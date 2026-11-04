function table_out = write_cross_evaluation(cfg)
%WRITE_CROSS_EVALUATION Evaluate each saved optimum under all five metrics.

names = string(cfg.objectives);
n = numel(names);
raw = nan(n, n);
for row = 1:n
    loaded = load(fullfile(cfg.results_dir, names(row) + ".mat"), 'result');
    metrics = loaded.result.metrics;
    raw(row, :) = [metrics.cost, metrics.hydraulic_entropy, ...
        metrics.chlorine_concentration, metrics.chlorine_entropy, metrics.todini];
end

normalized = raw;
normalized(:, 1) = raw(:, 1) ./ min(raw(:, 1));
for column = 2:n
    normalized(:, column) = raw(:, column) ./ max(raw(:, column));
end

diagonal_tolerance = 5e-4;
diagonal_error = abs(diag(normalized) - 1);
if any(diagonal_error > diagonal_tolerance)
    failed = names(diagonal_error > diagonal_tolerance);
    error('wdn:CrossEvaluationDiagonal', ...
        ['A saved single-objective design is beaten by another saved design ' ...
        'in its own metric: %s. Re-run the affected objective with all saved ' ...
        'cross-objective elites enabled.'], strjoin(failed, ', '));
end

labels = ["Cost"; "Hydraulic entropy"; "Chlorine concentration"; ...
    "Chlorine entropy"; "Todini index"];
table_out = array2table(normalized, 'VariableNames', ...
    {'Cost','HydraulicEntropy','ChlorineConcentration','ChlorineEntropy','Todini'});
table_out.OptimizedFor = labels;
table_out = movevars(table_out, 'OptimizedFor', 'Before', 1);
writetable(table_out, fullfile(cfg.results_dir, 'cross_evaluation.csv'));

raw_table = array2table(raw, 'VariableNames', ...
    {'Cost','HydraulicEntropy','ChlorineConcentration','ChlorineEntropy','Todini'});
raw_table.OptimizedFor = labels;
raw_table = movevars(raw_table, 'OptimizedFor', 'Before', 1);
writetable(raw_table, fullfile(cfg.results_dir, 'cross_evaluation_raw.csv'));
end
