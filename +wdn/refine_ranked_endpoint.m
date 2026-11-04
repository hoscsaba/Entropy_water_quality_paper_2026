function result = refine_ranked_endpoint(cfg, study, previous_result)
%REFINE_RANKED_ENDPOINT Re-run the full GA from the best ranked incumbent.

last_reduced = find(study.k < numel(cfg.design_link_ids), 1, 'last');
if isempty(last_reduced)
    result = previous_result;
    return;
end
metric_index = find(strcmp(study.metric_names, study.objective), 1);
values = reshape(study.metrics(:, last_reduced, metric_index), [], 1);
if strcmp(study.objective, 'cost')
    [~, best_row] = min(values);
else
    [~, best_row] = max(values);
end
seed = reshape(study.designs(best_row, last_reduced, :), 1, []);
cfg_refine = cfg;
cfg_refine.ga.seed_designs.(study.objective) = seed;
candidate = wdn.optimize_single_objective(cfg_refine, study.objective);

% A stochastic full run must never discard the feasible reduced incumbent.
[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
seed_metrics = wdn.evaluate_design(d, seed, cfg, model, true);
[c, ceq] = wdn.pressure_constraints(seed, d, cfg, model);
seed_violation = max([0; c(:); abs(ceq(:))]);
if seed_violation > cfg.ga.constraint_tolerance
    error('wdn:RankedEndpointSeedInfeasible', ...
        'Best reduced incumbent violates constraints by %.6g.', seed_violation);
end

candidate_value = objective_metric(candidate.metrics, study.objective);
previous_value = objective_metric(previous_result.metrics, study.objective);
seed_value = objective_metric(seed_metrics, study.objective);
if is_better(previous_value, candidate_value, study.objective)
    result = previous_result;
else
    result = candidate;
end
result_value = objective_metric(result.metrics, study.objective);
if is_better(seed_value, result_value, study.objective)
    result = candidate;
    result.design_diameters = seed;
    result.full_diameters = seed_metrics.full_diameters;
    result.metrics = seed_metrics;
    result.optimizer_value = signed_objective(seed_value, study.objective);
    result.max_constraint_violation = seed_violation;
    result.minimum_assessment_pressure = ...
        min(seed_metrics.pressures(model.pressure_node_indices));
    result.optimizer = 'ranked_continuation_incumbent';
end
result.endpoint_refined_from_ranked_subsets = true;
result.endpoint_seed_ranking = study.criterion_keys{best_row};
result.endpoint_seed_k = study.k(last_reduced);
end

function value = objective_metric(metrics, objective_name)
value = metrics.(objective_name);
end

function yes = is_better(a, b, objective_name)
if strcmp(objective_name, 'cost')
    yes = a < b;
else
    yes = a > b;
end
end

function value = signed_objective(physical_value, objective_name)
if strcmp(objective_name, 'cost')
    value = physical_value;
else
    value = -physical_value;
end
end
