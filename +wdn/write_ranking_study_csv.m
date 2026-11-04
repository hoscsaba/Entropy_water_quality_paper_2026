function write_ranking_study_csv(cfg, study, filename)
%WRITE_RANKING_STUDY_CSV Export a ranked-subset study in long table form.

% One row represents one ranking criterion and one nested subset size. The
% common format makes objective-specific studies directly comparable and is
% convenient for independent post-processing outside MATLAB.

row_count = numel(study.criterion_keys) * numel(study.k);
criterion = strings(row_count, 1);
k_value = zeros(row_count, 1);
metric_values = nan(row_count, numel(study.metric_names));
is_feasible = false(row_count, 1);
max_violation = nan(row_count, 1);
elapsed_seconds = nan(row_count, 1);
row = 0;
for q = 1:numel(study.criterion_keys)
    for j = 1:numel(study.k)
        row = row + 1;
        criterion(row) = string(study.criterion_keys{q});
        k_value(row) = study.k(j);
        metric_values(row, :) = reshape(study.metrics(q, j, :), 1, []);
        is_feasible(row) = study.is_feasible(q, j);
        max_violation(row) = study.max_constraint_violations(q, j);
        elapsed_seconds(row) = study.elapsed_seconds(q, j);
    end
end

rows = table(criterion, k_value, metric_values(:, 1), metric_values(:, 2), ...
    metric_values(:, 3), metric_values(:, 4), metric_values(:, 5), ...
    is_feasible, max_violation, elapsed_seconds, ...
    'VariableNames', {'Criterion','K','Cost','HydraulicEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini','IsFeasible', ...
    'MaxConstraintViolation','ElapsedSeconds'});
writetable(rows, fullfile(cfg.results_dir, filename));
end
