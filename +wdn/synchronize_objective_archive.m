function selections = synchronize_objective_archive(cfg)
%SYNCHRONIZE_OBJECTIVE_ARCHIVE Keep the best feasible design known per metric.
%   Finite stochastic searches can discover a design under objective A that
%   is also better than the saved incumbent for objective B. This function
%   updates B's published incumbent while preserving B's raw GA return for
%   audit. It makes the saved archive independent of objective execution order.

names = string(cfg.objectives);
records = cell(size(names));
values = nan(numel(names), numel(names));
for index = 1:numel(names)
    loaded = load(fullfile(cfg.results_dir, names(index) + ".mat"), 'result');
    records{index} = loaded.result;
    metrics = loaded.result.metrics;
    values(index, :) = [metrics.cost, metrics.hydraulic_entropy, ...
        metrics.chlorine_concentration, metrics.chlorine_entropy, metrics.todini];
    if loaded.result.max_constraint_violation > cfg.ga.constraint_tolerance
        error('wdn:ArchiveContainsInfeasibleDesign', ...
            '%s exceeds the configured pressure tolerance.', names(index));
    end
end

[~, best_source] = min(values(:, 1));
for metric_index = 2:numel(names)
    [~, best_source(metric_index)] = max(values(:, metric_index));
end
% Prefer the objective's own record when it is exactly tied with the shared
% best. This keeps repeated synchronization idempotent and preserves provenance.
for target = 1:numel(names)
    best_value = values(best_source(target), target);
    target_value = values(target, target);
    tie_tolerance = 1e-12 * max([1, abs(best_value), abs(target_value)]);
    if abs(target_value - best_value) <= tie_tolerance
        best_source(target) = target;
    end
end
selected_names = reshape(names(best_source), [], 1);
selections = table(names(:), selected_names, ...
    'VariableNames', {'Objective','SelectedFrom'});

for target = 1:numel(names)
    source = best_source(target);
    if source == target
        continue;
    end
    result = records{target};
    source_result = records{source};
    if ~isfield(result, 'optimizer_returned_design_diameters')
        result.optimizer_returned_design_diameters = result.design_diameters;
        result.optimizer_returned_full_diameters = result.full_diameters;
        result.optimizer_returned_metrics = result.metrics;
        result.optimizer_returned_value = result.optimizer_value;
    end
    result.design_diameters = source_result.design_diameters;
    result.full_diameters = source_result.full_diameters;
    result.metrics = source_result.metrics;
    result.max_constraint_violation = source_result.max_constraint_violation;
    result.minimum_assessment_pressure = source_result.minimum_assessment_pressure;
    result.optimizer_value = signed_value(values(source, target), target);
    result.incumbent_guard_applied = true;
    result.incumbent_source = char("shared archive: " + names(source) + " design");
    result.selected_from_objective = char(names(source));
    result.archive_synchronized_at = datetime('now', 'TimeZone', 'local');
    save(fullfile(cfg.results_dir, names(target) + ".mat"), 'result', 'cfg');
end
end

function value = signed_value(physical_value, metric_index)
if metric_index == 1
    value = physical_value;
else
    value = -physical_value;
end
end
