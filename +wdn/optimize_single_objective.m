function result = optimize_single_objective(cfg, objective_name)
%OPTIMIZE_SINGLE_OBJECTIVE Run one reproducible, sequential EPANET-backed GA.

wall_clock_start = tic;
cpu_time_start = cputime;

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));

nvars = numel(model.design_link_indices);
lb = cfg.minimum_diameter * ones(1, nvars);
ub = cfg.maximum_diameter * ones(1, nvars);
x0 = min(max(model.original_full_diameters(model.design_link_indices), lb), ub);
rng(cfg.ga.random_seed, 'twister');
fitness = @(x) wdn.objective_value(x, d, cfg, model, objective_name);
nonlcon = @(x) wdn.pressure_constraints(x, d, cfg, model);
has_builtin_ga = license('test', 'GADS_Toolbox') && ...
    exist('ga', 'file') == 2 && exist('optimoptions', 'file') == 2;
if has_builtin_ga
    initial_population = lb + rand(cfg.ga.population_size, nvars) .* (ub - lb);
    initial_population(1, :) = x0;
    elite_candidates = x0;
    elite_sources = "original design";
    next_seed_row = 2;
    if isfield(cfg.ga, 'feasible_interpolation_to_upper')
        fraction = cfg.ga.feasible_interpolation_to_upper;
        feasible_seed = x0 + fraction * (ub - x0);
        [seed_c, seed_ceq] = nonlcon(feasible_seed);
        seed_violation = max([0; seed_c(:); abs(seed_ceq(:))]);
        if seed_violation > cfg.ga.constraint_tolerance
            error('wdn:ConfiguredSeedInfeasible', ...
                'Configured feasible seed violates constraints by %.6g.', ...
                seed_violation);
        end
        initial_population(next_seed_row, :) = feasible_seed;
        elite_candidates(end + 1, :) = feasible_seed;
        elite_sources(end + 1, 1) = "configured feasible interpolation";
        next_seed_row = next_seed_row + 1;
    end
    % Reuse every compatible saved optimum as a cross-objective elite. This
    % is especially important when narrow two-sided head bands make feasible
    % random individuals rare; it also guarantees a fair cross-evaluation.
    for saved_objective = string(cfg.objectives)
        saved_path = fullfile(cfg.results_dir, saved_objective + ".mat");
        if ~isfile(saved_path) || next_seed_row > cfg.ga.population_size
            continue;
        end
        saved = load(saved_path, 'result');
        if isfield(saved, 'result') && ...
                numel(saved.result.design_diameters) == nvars
            candidate = min(max(saved.result.design_diameters(:)', lb), ub);
            [candidate_c, candidate_ceq] = nonlcon(candidate);
            candidate_violation = max([0; candidate_c(:); abs(candidate_ceq(:))]);
            if candidate_violation <= cfg.ga.constraint_tolerance
                initial_population(next_seed_row, :) = candidate;
                elite_candidates(end + 1, :) = candidate; %#ok<AGROW>
                elite_sources(end + 1, 1) = ...
                    "saved " + saved_objective + " optimum"; %#ok<AGROW>
                next_seed_row = next_seed_row + 1;
            end
        end
    end
    if isfield(cfg.ga, 'seed_designs') && ...
            isfield(cfg.ga.seed_designs, char(objective_name))
        seed_design = cfg.ga.seed_designs.(char(objective_name));
        if numel(seed_design) ~= nvars
            error('wdn:SeedDesignSize', ...
                'Seed design for %s has %d values; expected %d.', ...
                objective_name, numel(seed_design), nvars);
        end
        seed_design = min(max(seed_design(:)', lb), ub);
        % Upper-bound projection is valid only for one-sided minimum-pressure
        % constraints. It is not valid when either explicit pressure anchors
        % or a finite maximum-pressure constraint makes feasibility two-sided.
        has_pressure_anchors = isfield(cfg, 'pressure_anchor_node_ids') && ...
            ~isempty(cfg.pressure_anchor_node_ids);
        has_finite_maximum_pressure = isfield(cfg, 'maximum_pressure') && ...
            isfinite(cfg.maximum_pressure);
        if ~has_pressure_anchors && ~has_finite_maximum_pressure
            [seed_design, ~, ~] = wdn.project_feasible( ...
                seed_design, ub, nonlcon, cfg.ga.constraint_tolerance);
        end
        if next_seed_row <= cfg.ga.population_size
            initial_population(next_seed_row, :) = seed_design;
            elite_candidates(end + 1, :) = seed_design;
            elite_sources(end + 1, 1) = "configured " + objective_name + " seed";
        end
    end
    options = optimoptions('ga', ...
        'Display', cfg.ga.display, ...
        'PopulationSize', cfg.ga.population_size, ...
        'MaxGenerations', cfg.ga.max_generations, ...
        'MaxStallGenerations', cfg.ga.max_stall_generations, ...
        'FunctionTolerance', cfg.ga.function_tolerance, ...
        'ConstraintTolerance', cfg.ga.constraint_tolerance, ...
        'NonlinearConstraintAlgorithm', 'penalty', ...
        'InitialPopulationMatrix', initial_population, ...
        'UseParallel', false);
    [x, fval, ga_exitflag, ga_output] = ga( ...
        fitness, nvars, [], [], [], [], lb, ub, nonlcon, options);
    if cfg.ga.use_hybrid_patternsearch && exist('patternsearch', 'file') == 2
        hybrid_options = optimoptions('patternsearch', ...
            'Display', 'final', ...
            'ConstraintTolerance', cfg.ga.constraint_tolerance, ...
            'FunctionTolerance', cfg.ga.function_tolerance, ...
            'MeshTolerance', cfg.ga.function_tolerance, ...
            'UseParallel', false);
        [x, fval, exitflag, hybrid_output] = patternsearch( ...
            fitness, x, [], [], [], [], lb, ub, nonlcon, hybrid_options);
        % This handle closes over the live EPANET object and must not be
        % serialized into a reusable result MAT-file.
        if isfield(hybrid_output, 'function')
            hybrid_output = rmfield(hybrid_output, 'function');
        end
        output.ga = ga_output;
        output.ga_exitflag = ga_exitflag;
        output.patternsearch = hybrid_output;
        optimizer_name = 'matlab_ga_patternsearch';
    else
        exitflag = ga_exitflag;
        output = ga_output;
        optimizer_name = 'matlab_ga';
    end
else
    warning('wdn:FallbackGA', ['Global Optimization Toolbox is unavailable; ' ...
        'using the sequential wdn.simple_ga fallback.']);
    [x, fval, exitflag, output] = wdn.simple_ga( ...
        fitness, nonlcon, x0, lb, ub, cfg.ga);
    optimizer_name = 'wdn_simple_ga';
    elite_candidates = x0;
    elite_sources = "original design";
end

% MATLAB's constrained GA can return a solution that is worse than a known
% feasible cross-objective elite, particularly when the elite was generated
% by an objective optimized later in an earlier sequential run.  Re-evaluate
% the documented warm starts and retain the best feasible incumbent.  This
% makes the result independent of objective execution order and guarantees
% that a cross-evaluation diagonal cannot be beaten by another saved design.
incumbent_guard_applied = false;
incumbent_source = "optimizer result";
best_value = fval;
for candidate_index = 1:size(elite_candidates, 1)
    candidate = elite_candidates(candidate_index, :);
    [candidate_c, candidate_ceq] = nonlcon(candidate);
    candidate_violation = max([0; candidate_c(:); abs(candidate_ceq(:))]);
    if candidate_violation > cfg.ga.constraint_tolerance
        continue;
    end
    candidate_value = fitness(candidate);
    if candidate_value < best_value
        x = candidate;
        fval = candidate_value;
        best_value = candidate_value;
        incumbent_guard_applied = true;
        incumbent_source = elite_sources(candidate_index);
    end
end
metrics = wdn.evaluate_design(d, x, cfg, model);
has_pressure_anchors = isfield(cfg, 'pressure_anchor_node_ids') && ...
    ~isempty(cfg.pressure_anchor_node_ids);
has_finite_maximum_pressure = isfield(cfg, 'maximum_pressure') && ...
    isfinite(cfg.maximum_pressure);
if has_pressure_anchors || has_finite_maximum_pressure
    feasibility_projection_applied = false;
    projected_violation = NaN;
else
    [x, feasibility_projection_applied, projected_violation] = ...
        wdn.project_feasible(x, ub, nonlcon, cfg.ga.constraint_tolerance);
end
if feasibility_projection_applied
    fval = fitness(x);
    metrics = wdn.evaluate_design(d, x, cfg, model);
end
[constraint_values, equality_values] = wdn.pressure_constraints(x, d, cfg, model);
max_constraint_violation = max([0; constraint_values(:); abs(equality_values(:))]);
if max_constraint_violation > cfg.ga.constraint_tolerance
    error('wdn:InfeasibleOptimizationResult', ...
        'Optimizer returned a design with maximum constraint violation %.6g.', ...
        max_constraint_violation);
end

result.network_id = cfg.id;
result.objective = char(objective_name);
result.design_link_ids = cfg.design_link_ids;
result.design_diameters = x(:)';
result.full_link_ids = cellstr(model.link_ids);
result.full_diameters = metrics.full_diameters;
result.optimizer_value = fval;
result.metrics = metrics;
result.exitflag = exitflag;
result.output = output;
result.optimizer = optimizer_name;
result.random_seed = cfg.ga.random_seed;
result.max_constraint_violation = max_constraint_violation;
result.minimum_assessment_pressure = min(metrics.pressures(model.pressure_node_indices));
result.feasibility_projection_applied = feasibility_projection_applied;
result.pre_validation_projected_violation = projected_violation;
result.incumbent_guard_applied = incumbent_guard_applied;
result.incumbent_source = char(incumbent_source);
result.elapsed_time_seconds = toc(wall_clock_start);
result.cpu_time_seconds = cputime - cpu_time_start;
result.created_at = datetime('now', 'TimeZone', 'local');
end
