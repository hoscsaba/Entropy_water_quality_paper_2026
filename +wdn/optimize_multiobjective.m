function result = optimize_multiobjective(cfg, objective_names)
%OPTIMIZE_MULTIOBJECTIVE Reproducible two-objective Anytown Pareto search.
% The calculation uses exactly the same 38 physical Anytown design links,
% pressure limits, pressure-anchor constraints, EPANET model, and objective
% implementations as the validated single-objective calculations.

if nargin < 2
    objective_names = {'hydraulic_entropy', 'chlorine_concentration'};
end
objective_names = string(objective_names);
if numel(objective_names) ~= 2
    error('wdn:MultiobjectivePairSize', ...
        'Exactly two objective names must be supplied.');
end
allowed_objectives = ["cost", "hydraulic_entropy", ...
    "chlorine_concentration", "chlorine_entropy", "todini"];
if ~all(ismember(objective_names, allowed_objectives))
    error('wdn:UnknownMultiobjectiveMetric', 'Unknown objective name.');
end
objective_sign = -ones(1, 2); % MATLAB minimizes; physical metrics maximize.
objective_sign(objective_names == "cost") = 1;
requires_quality = any(ismember(objective_names, ...
    ["chlorine_concentration", "chlorine_entropy"]));

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));

nvars = numel(model.design_link_indices);
lb = cfg.minimum_diameter * ones(1, nvars);
ub = cfg.maximum_diameter * ones(1, nvars);
random_seed = cfg.multiobjective.random_seed;
if isequal(objective_names, ["cost", "hydraulic_entropy"]) && ...
        isfield(cfg.multiobjective, 'cost_entropy_random_seed')
    random_seed = cfg.multiobjective.cost_entropy_random_seed;
end
rng(random_seed, 'twister');

% containers.Map lets the objective and nonlinear-constraint callbacks share
% one EPANET hydraulic/quality evaluation for every identical candidate.
evaluation_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
fitness = @candidate_objectives;
nonlcon = @candidate_constraints;

seed_matrix = load_validated_seeds();
options = optimoptions('gamultiobj', ...
    'Display', cfg.multiobjective.display, ...
    'PopulationSize', cfg.multiobjective.population_size, ...
    'MaxGenerations', cfg.multiobjective.max_generations, ...
    'MaxStallGenerations', cfg.multiobjective.max_stall_generations, ...
    'FunctionTolerance', cfg.multiobjective.function_tolerance, ...
    'ConstraintTolerance', cfg.ga.constraint_tolerance, ...
    'ParetoFraction', cfg.multiobjective.pareto_fraction, ...
    'CrossoverFraction', 0.80, ...
    'MutationFcn', @mutationadaptfeasible, ...
    'InitialPopulationMatrix', seed_matrix, ...
    'UseParallel', false);

[designs, optimizer_values, exitflag, output, population, scores] = ...
    gamultiobj(fitness, nvars, [], [], [], [], lb, ub, nonlcon, options);

num_points = size(designs, 1);
if num_points < 2
    error('wdn:MultiobjectiveFrontTooSmall', ...
        'gamultiobj returned only %d feasible Pareto point(s).', num_points);
end

% Full water-quality metrics are evaluated for the final front even when
% chlorine was not an optimization objective. This supports independent
% coloring and marker-size diagnostics without slowing every GA candidate.
metrics = repmat(wdn.evaluate_design(d, designs(1, :), cfg, model, true), ...
    num_points, 1);
max_constraint_violation = zeros(num_points, 1);
for k = 1:num_points
    metrics(k) = wdn.evaluate_design(d, designs(k, :), cfg, model, true);
    [c, ceq] = constraints_from_metrics(metrics(k));
    max_constraint_violation(k) = max([0; c(:); abs(ceq(:))]);
end
if any(max_constraint_violation > cfg.ga.constraint_tolerance)
    error('wdn:InfeasibleMultiobjectiveResult', ...
        'The saved Pareto set contains an infeasible design (max violation %.6g).', ...
        max(max_constraint_violation));
end

hydraulic_entropy = arrayfun(@(m) m.hydraulic_entropy, metrics)';
chlorine_concentration = arrayfun(@(m) m.chlorine_concentration, metrics)';
chlorine_entropy = arrayfun(@(m) m.chlorine_entropy, metrics)';
cost = arrayfun(@(m) m.cost, metrics)';
minimum_pressure = arrayfun(@(m) ...
    min(m.pressures(model.pressure_node_indices)), metrics)';
anchor_head_deviation = arrayfun(@(m) max(abs( ...
    m.heads(model.pressure_anchor_node_indices) - ...
    cfg.pressure_anchor_target_heads(:))), metrics)';

% Sort by the first physical objective to make the stored front and its
% plotted connecting line deterministic and easy to inspect.
primary_values = arrayfun(@(m) ...
    m.(char(objective_names(1))), metrics);
[~, order] = sort(primary_values);
designs = designs(order, :);
optimizer_values = optimizer_values(order, :);
metrics = metrics(order);
chlorine_concentration = chlorine_concentration(order);
chlorine_entropy = chlorine_entropy(order);
cost = cost(order);
minimum_pressure = minimum_pressure(order);
anchor_head_deviation = anchor_head_deviation(order);
max_constraint_violation = max_constraint_violation(order);
hydraulic_entropy = hydraulic_entropy(order);

result.network_id = cfg.id;
result.objectives = cellstr(objective_names);
result.design_link_ids = cfg.design_link_ids;
result.designs = designs;
result.optimizer_values = optimizer_values;
result.metrics = metrics;
result.hydraulic_entropy = hydraulic_entropy;
result.chlorine_concentration = chlorine_concentration;
result.chlorine_entropy = chlorine_entropy;
result.cost = cost;
result.minimum_pressure = minimum_pressure;
result.anchor_head_deviation = anchor_head_deviation;
result.max_constraint_violation = max_constraint_violation;
result.exitflag = exitflag;
result.output = output;
result.final_population = population;
result.final_scores = scores;
result.optimizer = 'matlab_gamultiobj';
result.random_seed = random_seed;
result.created_at = datetime('now', 'TimeZone', 'local');

    function metrics_value = cached_evaluation(x)
        key = sprintf('%.12g,', x);
        if isKey(evaluation_cache, key)
            metrics_value = evaluation_cache(key);
            return;
        end
        metrics_value = wdn.evaluate_design(d, x, cfg, model, requires_quality);
        evaluation_cache(key) = metrics_value;
    end

    function f = candidate_objectives(x)
        candidate = cached_evaluation(x);
        f = [objective_sign(1) * candidate.(char(objective_names(1))), ...
            objective_sign(2) * candidate.(char(objective_names(2)))];
        if any(~isfinite(f))
            f(:) = realmax('double') / 100;
        end
    end

    function [c, ceq] = candidate_constraints(x)
        candidate = cached_evaluation(x);
        [c, ceq] = constraints_from_metrics(candidate);
    end

    function [c, ceq] = constraints_from_metrics(candidate)
        assessment_pressure = candidate.pressures(model.pressure_node_indices);
        c = cfg.minimum_pressure - assessment_pressure;
        if isfinite(cfg.maximum_pressure)
            c = [c; assessment_pressure - cfg.maximum_pressure];
        end
        anchor_head = candidate.heads(model.pressure_anchor_node_indices);
        c = [c; abs(anchor_head - cfg.pressure_anchor_target_heads(:)) - ...
            cfg.pressure_anchor_head_tolerance];
        c = c(:);
        ceq = [];
    end

    function seeds = load_validated_seeds()
        seeds = zeros(0, nvars);
        for objective = string(cfg.objectives)
            result_file = fullfile(cfg.results_dir, objective + ".mat");
            if ~isfile(result_file)
                continue;
            end
            saved = load(result_file, 'result');
            if ~isfield(saved, 'result') || ...
                    numel(saved.result.design_diameters) ~= nvars || ...
                    ~isfield(saved.result, 'max_constraint_violation') || ...
                    saved.result.max_constraint_violation > cfg.ga.constraint_tolerance
                continue;
            end
            seeds(end + 1, :) = min(max( ...
                saved.result.design_diameters(:)', lb), ub); %#ok<AGROW>
        end
        if size(seeds, 1) < 2
            error('wdn:MultiobjectiveSeedsMissing', ...
                'At least two validated single-objective Anytown results are required.');
        end
        seeds = unique(seeds, 'rows', 'stable');
    end
end
