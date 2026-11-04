function study = optimize_ranked_subsets(cfg, ranking, objective_name, k_values, full_result)
%OPTIMIZE_RANKED_SUBSETS Optimize nested ranked subsets for one objective.
% Nonselected pipes retain their original INP diameters. If cfg.ranking.cache_dir
% is configured, every (objective, criterion, K) result is saved separately and
% reused on later calls, so extending k_values never repeats completed runs.

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
old_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(old_dir));

objective_name = char(objective_name);
x_original = model.original_full_diameters(model.design_link_indices);
n_criteria = numel(ranking.criterion_keys);
k_values = double(k_values(:)');
metric_names = {'cost','hydraulic_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
metrics = nan(n_criteria, numel(k_values), numel(metric_names));
designs = nan(n_criteria, numel(k_values), numel(x_original));
violations = nan(n_criteria, numel(k_values));
is_feasible = false(n_criteria, numel(k_values));
elapsed_seconds = zeros(n_criteria, numel(k_values));

lb_full = cfg.minimum_diameter * ones(size(x_original));
ub_full = cfg.maximum_diameter * ones(size(x_original));
original_metrics = wdn.evaluate_design(d, x_original, cfg, model, true);
[original_c, original_ceq] = wdn.pressure_constraints(x_original, d, cfg, model);
original_violation = max([0; original_c(:); abs(original_ceq(:))]);
cache_enabled = isfield(cfg, 'ranking') && ...
    isfield(cfg.ranking, 'cache_dir') && ~isempty(cfg.ranking.cache_dir);
if cache_enabled && ~exist(cfg.ranking.cache_dir, 'dir')
    mkdir(cfg.ranking.cache_dir);
end

for q = 1:n_criteria
    current_feasible = [];
    for j = 1:numel(k_values)
        k = k_values(j);
        run_start = tic;
        exitflag = NaN;
        generations = 0;
        loaded_from_cache = false;
        signature = ranking_cache_signature( ...
            cfg, ranking, objective_name, q, k, full_result);
        cache_file = '';
        if cache_enabled
            criterion_dir = fullfile(cfg.ranking.cache_dir, objective_name, ...
                matlab.lang.makeValidName(ranking.criterion_keys{q}));
            if ~exist(criterion_dir, 'dir'), mkdir(criterion_dir); end
            cache_file = fullfile(criterion_dir, sprintf('k_%03d.mat', k));
            if isfile(cache_file)
                saved_cache = load(cache_file, 'entry');
                if ~isfield(saved_cache, 'entry') || ...
                        ~isfield(saved_cache.entry, 'cache_signature') || ...
                        ~strcmp(saved_cache.entry.cache_signature, signature)
                    error('wdn:RankingCacheMismatch', ...
                        ['Cached ranking result is incompatible with the current ' ...
                        'configuration: %s'], cache_file);
                end
                entry = saved_cache.entry;
                candidate = entry.design_diameters;
                evaluated = entry.metrics;
                violation = entry.max_constraint_violation;
                accepted = entry.is_feasible;
                exitflag = entry.exitflag;
                generations = entry.generations;
                run_elapsed = entry.elapsed_seconds;
                loaded_from_cache = true;
            end
        end
        if loaded_from_cache
            % Values are assigned above and processed by the common storage
            % block below. A feasible cached design becomes the incumbent for
            % the next newly requested, larger nested subset.
        elseif k == 0
            candidate = x_original;
            evaluated = original_metrics;
            violation = original_violation;
            accepted = violation <= cfg.ga.constraint_tolerance;
        elseif k == numel(x_original)
            candidate = full_result.design_diameters(:)';
            evaluated = full_result.metrics;
            [c, ceq] = wdn.pressure_constraints(candidate, d, cfg, model);
            violation = max([0; c(:); abs(ceq(:))]);
            accepted = violation <= cfg.ga.constraint_tolerance;
            exitflag = full_result.exitflag;
            generations = full_result.output.generations;
        else
            selected = ranking.orders(1:k, q)';
            lb = lb_full(selected);
            ub = ub_full(selected);
            map_design = @(y) replace_subset(x_original, selected, y);
            fitness = @(y) wdn.objective_value( ...
                map_design(y), d, cfg, model, objective_name);
            nonlcon = @(y) constraints_for_subset( ...
                y, map_design, d, cfg, model);
            feasible_seed_full = [];
            if isempty(current_feasible)
                [feasible_seed, seed_violation] = find_feasible_seed( ...
                    x_original(selected), full_result.design_diameters(selected), ...
                    lb, ub, map_design, d, cfg, model);
                if seed_violation <= cfg.ga.constraint_tolerance
                    feasible_seed_full = map_design(feasible_seed);
                end
            end
            % Every reduced problem uses the same random seed and the same
            % 100-by-100 GA budget as the validated full-network optimum.
            rng(cfg.ga.random_seed, 'twister');
            initial = lb + rand(cfg.ga.population_size, k) .* (ub - lb);
            initial(1, :) = x_original(selected);
            if ~isempty(current_feasible)
                initial(1, :) = current_feasible(selected);
            elseif ~isempty(feasible_seed_full)
                initial(1, :) = feasible_seed_full(selected);
            end
            initial(2, :) = min(max(full_result.design_diameters(selected), lb), ub);
            options = optimoptions('ga', ...
                'Display', cfg.ranking.display, ...
                'PopulationSize', cfg.ga.population_size, ...
                'MaxGenerations', cfg.ga.max_generations, ...
                'MaxStallGenerations', cfg.ga.max_stall_generations, ...
                'FunctionTolerance', cfg.ga.function_tolerance, ...
                'ConstraintTolerance', cfg.ga.constraint_tolerance, ...
                'NonlinearConstraintAlgorithm', 'penalty', ...
                'InitialPopulationMatrix', initial, ...
                'UseParallel', false);
            [y, candidate_fitness, exitflag, output] = ga( ...
                fitness, k, [], [], [], [], lb, ub, nonlcon, options);
            candidate = map_design(y);
            [candidate_c, candidate_ceq] = wdn.pressure_constraints( ...
                candidate, d, cfg, model);
            violation = max([0; candidate_c(:); abs(candidate_ceq(:))]);
            accepted = violation <= cfg.ga.constraint_tolerance;
            if accepted && ~isempty(current_feasible)
                incumbent_fitness = wdn.objective_value( ...
                    current_feasible, d, cfg, model, objective_name);
                if candidate_fitness > incumbent_fitness
                    candidate = current_feasible;
                    [candidate_c, candidate_ceq] = wdn.pressure_constraints( ...
                        candidate, d, cfg, model);
                    violation = max([0; candidate_c(:); abs(candidate_ceq(:))]);
                end
            elseif ~accepted && (~isempty(current_feasible) || ...
                    ~isempty(feasible_seed_full))
                if ~isempty(current_feasible)
                    candidate = current_feasible;
                else
                    candidate = feasible_seed_full;
                end
                [candidate_c, candidate_ceq] = wdn.pressure_constraints( ...
                    candidate, d, cfg, model);
                violation = max([0; candidate_c(:); abs(candidate_ceq(:))]);
                accepted = true;
            end
            if accepted
                evaluated = wdn.evaluate_design(d, candidate, cfg, model, true);
            else
                evaluated = struct();
            end
            generations = output.generations;
        end

        if ~loaded_from_cache
            run_elapsed = toc(run_start);
            if cache_enabled
                entry.cache_signature = signature;
                entry.network_id = cfg.id;
                entry.objective = objective_name;
                entry.criterion_key = ranking.criterion_keys{q};
                entry.k = k;
                entry.design_diameters = candidate;
                entry.metrics = evaluated;
                entry.max_constraint_violation = violation;
                entry.is_feasible = accepted && ...
                    violation <= cfg.ga.constraint_tolerance;
                entry.exitflag = exitflag;
                entry.generations = generations;
                entry.elapsed_seconds = run_elapsed;
                entry.created_at = datetime('now', 'TimeZone', 'local');
                save(cache_file, 'entry');
            end
        end

        designs(q, j, :) = candidate;
        violations(q, j) = violation;
        is_feasible(q, j) = accepted && ...
            violation <= cfg.ga.constraint_tolerance;
        % The original K=0 metrics are intentionally reported even though
        % the pressure-anchor constraint is violated. Infeasible optimized
        % subsets are left as NaN and therefore appear as gaps in the plot.
        if k == 0 || is_feasible(q, j)
            for m = 1:numel(metric_names)
                metrics(q, j, m) = evaluated.(metric_names{m});
            end
        end
        if is_feasible(q, j)
            current_feasible = candidate;
        end
        elapsed_seconds(q, j) = run_elapsed;
        if loaded_from_cache
            status = 'cached';
        elseif k == 0 && is_feasible(q, j)
            status = 'original-feasible';
        elseif k == 0
            status = 'original-infeasible';
        elseif is_feasible(q, j)
            status = 'feasible';
        else
            status = 'infeasible-no-point';
        end
        fprintf('%s / %s: K=%d, status=%s, violation=%.6g, exit=%g, gen=%d\n', ...
            objective_name, ranking.criterion_labels{q}, k, status, ...
            violation, exitflag, generations);
    end
end

study.network_id = cfg.id;
study.objective = objective_name;
study.pressure_anchor_method = isfield(cfg, 'pressure_anchor_node_ids') && ...
    ~isempty(cfg.pressure_anchor_node_ids);
study.k = k_values;
study.criterion_keys = ranking.criterion_keys;
study.criterion_labels = ranking.criterion_labels;
study.metric_names = metric_names;
study.metrics = metrics;
study.designs = designs;
study.max_constraint_violations = violations;
study.is_feasible = is_feasible;
study.elapsed_seconds = elapsed_seconds;
study.original_design = x_original;
study.original_metrics = original_metrics;
study.original_constraint_violation = original_violation;
study.full_result_objective = full_result.objective;
study.created_at = datetime('now', 'TimeZone', 'local');
end

function signature = ranking_cache_signature( ...
        cfg, ranking, objective_name, criterion_index, k, full_result)
ordered_ids = strjoin(string(ranking.ordered_link_ids(:, criterion_index)), ',');
full_checksum = [sum(full_result.design_diameters), ...
    sum(full_result.design_diameters.^2), numel(full_result.design_diameters)];
signature = sprintf([ ...
    'v2|network=%s|objective=%s|criterion=%s|k=%d|seed=%d|pop=%d|' ...
    'gen=%d|stall=%d|ftol=%.12g|ctol=%.12g|lb=%.12g|ub=%.12g|' ...
    'full=%.12g,%.12g,%d|order=%s'], ...
    cfg.id, objective_name, ranking.criterion_keys{criterion_index}, k, ...
    cfg.ga.random_seed, cfg.ga.population_size, cfg.ga.max_generations, ...
    cfg.ga.max_stall_generations, cfg.ga.function_tolerance, ...
    cfg.ga.constraint_tolerance, cfg.minimum_diameter, cfg.maximum_diameter, ...
    full_checksum(1), full_checksum(2), full_checksum(3), ordered_ids);
end

function x = replace_subset(reference, selected, values)
x = reference;
x(selected) = values;
end

function [c, ceq] = constraints_for_subset(y, map_design, d, cfg, model)
[c, ceq] = wdn.pressure_constraints(map_design(y), d, cfg, model);
end

function [best_y, best_violation] = find_feasible_seed( ...
        original_y, full_y, lb, ub, map_design, d, cfg, model)
% Use bounded nonlinear least squares only to locate the narrow anchor band;
% the subsequent engineering objective is still optimized by the full GA.
starts = [original_y(:)'; min(max(full_y(:)', lb), ub); (lb + ub) / 2];
best_y = starts(1, :);
best_violation = inf;
options = optimoptions('lsqnonlin', 'Display','off', ...
    'MaxIterations',500, 'MaxFunctionEvaluations',10000, ...
    'FunctionTolerance',1e-12, 'StepTolerance',1e-10, ...
    'OptimalityTolerance',1e-10, 'FiniteDifferenceType','central');
for row = 1:size(starts, 1)
    residual = @(y) feasibility_residual(y, map_design, d, cfg, model);
    try
        y = lsqnonlin(residual, starts(row, :), lb, ub, options);
    catch
        y = starts(row, :);
    end
    [c, ceq] = wdn.pressure_constraints(map_design(y), d, cfg, model);
    violation = max([0; c(:); abs(ceq(:))]);
    if violation < best_violation
        best_y = y;
        best_violation = violation;
    end
end
end

function residual = feasibility_residual(y, map_design, d, cfg, model)
x = map_design(y);
wdn.apply_design(d, x, cfg, model);
d.solveCompleteHydraulics;
pressure = double(d.getNodePressure);
pressure = pressure(:);
head = double(d.getNodeHydraulicHead);
head = head(:);
residual = [ ...
    max(cfg.minimum_pressure - pressure(model.pressure_node_indices), 0); ...
    max(pressure(model.pressure_node_indices) - cfg.maximum_pressure, 0)];
if isfield(model, 'pressure_anchor_node_indices') && ...
        ~isempty(model.pressure_anchor_node_indices)
    residual = [residual; head(model.pressure_anchor_node_indices) - ...
        double(cfg.pressure_anchor_target_heads(:))];
end
residual = residual(:);
end
