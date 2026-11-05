function make_objective_relationship_summary(staci_root, mex_dir)
%MAKE_OBJECTIVE_RELATIONSHIP_SUMMARY Cross-effects and rank associations.
% This post-processing script uses saved optimization results only. It does
% not run a genetic algorithm. The Anytown reference is the documented
% pressure-anchor-feasible design; Balerma uses its original feasible design.

close all;

project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(project_root, '-begin');
addpath(fullfile(staci_root,'matlab'),mex_dir);
paper_dir = fullfile(project_root, 'manuscript', 'generated');
paper_figure_dir = fullfile(paper_dir, 'figures');
output_dir = fullfile(project_root, 'results_staci', 'objective_relationships');
if ~isfolder(output_dir), mkdir(output_dir); end
if ~isfolder(paper_figure_dir), mkdir(paper_figure_dir); end
table_dir = fullfile(paper_dir, 'tables');
if ~isfolder(table_dir), mkdir(table_dir); end

metric_names = {'cost','hydraulic_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
metric_labels = {'Cost','Hyd. ent.','Cl conc.', ...
    'Cl ent.','Todini'};
objective_labels = {'Cost','Hydraulic entropy','Cl concentration', ...
    'Cl entropy','Todini index'};
network_ids = {'anytown','balerma'};
network_labels = {'Anytown','Balerma'};

cross_effects = cell(1, numel(network_ids));
reference_metrics = cell(1, numel(network_ids));
for n = 1:numel(network_ids)
    network_dir = fullfile(project_root, 'networks', network_ids{n});
    cfg = local_network_config(network_dir);
    cfg.results_dir = fullfile(network_dir,'results_staci');

    if strcmp(network_ids{n}, 'anytown')
        baseline = load(fullfile(cfg.results_dir,'baseline.mat'),'baseline');
        st = StaciModel(fullfile(network_dir,'input', ...
            'network_staci_fixed_load.inp'));
        cleanup_network = onCleanup(@() st.release());
        x0 = double(baseline.baseline.design_diameters(:));
        x_ref = x0 + cfg.ga.feasible_interpolation_to_upper * ...
            (cfg.maximum_diameter - x0);
        reference = wdn.evaluate_staci_design(st,cfg,x_ref, ...
            string(baseline.baseline.full_link_ids(:)), ...
            baseline.baseline.full_diameters);
        clear cleanup_network st
    else
        baseline = load(fullfile(cfg.results_dir, 'baseline.mat'));
        reference = local_result_struct(baseline).metrics;
    end
    reference_metrics{n} = local_metric_vector(reference, metric_names);

    optimized = zeros(numel(metric_names), numel(metric_names));
    for i = 1:numel(metric_names)
        result = local_load_full_result(cfg, network_ids{n}, metric_names{i});
        optimized(i, :) = local_metric_vector(result.metrics, metric_names);
    end
    raw_change = 100 * (optimized ./ reference_metrics{n} - 1);
    beneficial_change = raw_change;
    beneficial_change(:, 1) = -beneficial_change(:, 1); % lower cost is better
    color_value = zeros(size(beneficial_change));
    for j = 1:size(beneficial_change, 2)
        scale = max(abs(beneficial_change(:, j)));
        if scale > 0
            color_value(:, j) = beneficial_change(:, j) / scale;
        end
    end
    cross_effects{n} = struct('raw_change_percent', raw_change, ...
        'beneficial_change_percent', beneficial_change, ...
        'column_normalized_color', color_value, ...
        'optimized_metrics', optimized);
end

figure_handle = figure('Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 22 10.6]);
layout = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
axes_handles = gobjects(1, numel(network_ids));
for n = 1:numel(network_ids)
    ax = nexttile(layout, n);
    axes_handles(n) = ax;
    imagesc(ax, cross_effects{n}.column_normalized_color, [-1 1]);
    axis(ax, 'image');
    title(ax, network_labels{n}, 'FontWeight', 'bold');
    xticks(ax, 1:numel(metric_names));
    xticklabels(ax, metric_labels);
    xtickangle(ax, 0);
    yticks(ax, 1:numel(metric_names));
    if n == 1
        yticklabels(ax, objective_labels);
        ylabel(ax, 'Optimized objective');
    else
        yticklabels(ax, {});
    end
    ax.FontSize = 10;
    ax.TickLength = [0 0];
    ax.XGrid = 'off';
    ax.YGrid = 'off';
    for i = 1:numel(metric_names)
        for j = 1:numel(metric_names)
            value = cross_effects{n}.beneficial_change_percent(i, j);
            color = [0 0 0];
            if abs(cross_effects{n}.column_normalized_color(i, j)) > 0.63
                color = [1 1 1];
            end
            text(ax, j, i, sprintf('%+.2g%%', value), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 8, 'FontWeight', 'bold', 'Color', color);
        end
    end
end
colormap(figure_handle, local_diverging_map(257));
cb = colorbar(axes_handles(end), 'eastoutside');
cb.Label.String = 'Column-normalized beneficial change';
cb.Ticks = [-1 0 1];
cb.TickLabels = {'worse','neutral','better'};

png_file = fullfile(paper_figure_dir, 'figure14_objective_cross_effects.png');
svg_file = fullfile(paper_figure_dir, 'figure14_objective_cross_effects.svg');
exportgraphics(figure_handle, png_file, 'Resolution', 600);
exportgraphics(figure_handle, svg_file, 'ContentType', 'vector');
close(figure_handle);

correlation_rows = local_ranking_correlations(project_root, network_ids, ...
    metric_names, metric_labels);
correlation_csv = fullfile(output_dir, 'ranking_trajectory_correlations.csv');
writetable(correlation_rows, correlation_csv);
local_write_latex_table(correlation_rows, ...
    fullfile(table_dir, 'objective_ranking_correlations.tex'));

cross_csv_rows = local_cross_effect_table(cross_effects, network_ids, ...
    objective_labels, metric_labels);
writetable(cross_csv_rows, fullfile(output_dir, 'full_optimum_cross_effects.csv'));
save(fullfile(output_dir, 'objective_relationship_summary.mat'), ...
    'cross_effects', 'reference_metrics', 'correlation_rows', ...
    'metric_names', 'metric_labels', 'network_ids');

fprintf('Created %s\n', png_file);
fprintf('Created %s\n', svg_file);
fprintf('Created %s\n', correlation_csv);
end

function cfg = local_network_config(network_dir)
addpath(network_dir, '-begin');
path_cleanup = onCleanup(@() rmpath(network_dir));
cfg = network_config(network_dir);
clear path_cleanup
end

function result = local_load_full_result(cfg, ~, objective)
loaded = load(fullfile(cfg.results_dir, [objective '.mat']));
result = local_result_struct(loaded);
end

function result = local_result_struct(loaded)
if isfield(loaded, 'result')
    result = loaded.result;
elseif isfield(loaded, 'baseline')
    result = loaded.baseline;
else
    fields = fieldnames(loaded);
    keep = fields(structfun(@isstruct, loaded));
    if isempty(keep)
        error('No result structure was found in the MAT file.');
    end
    result = loaded.(keep{1});
end
end

function values = local_metric_vector(metrics, metric_names)
values = zeros(1, numel(metric_names));
for j = 1:numel(metric_names)
    values(j) = metrics.(metric_names{j});
end
end

function rows = local_ranking_correlations(project_root, network_ids, ...
        metric_names, metric_labels)
pairs = nchoosek(1:numel(metric_names), 2);
records = cell(size(pairs, 1), 1);
for p = 1:size(pairs, 1)
    records{p} = struct('pair', sprintf('%s -- %s', ...
        metric_labels{pairs(p,1)}, metric_labels{pairs(p,2)}));
end
study_objectives = {'cost','hydraulic_entropy', ...
    'chlorine_concentration','chlorine_entropy'};
study_files = {'ranking_cost_study.mat','ranking_entropy_study.mat', ...
    'ranking_chlorine_concentration_study.mat', ...
    'ranking_chlorine_entropy_study.mat'};

stats = cell(numel(network_ids), size(pairs, 1));
for n = 1:numel(network_ids)
    result_dir = fullfile(project_root, 'networks', network_ids{n}, 'results_staci');
    rho_by_pair = cell(size(pairs, 1), 1);
    for s = 1:numel(study_files)
        loaded = load(fullfile(result_dir, study_files{s}));
        study = local_find_study(loaded, study_objectives{s});
        for criterion = 1:size(study.metrics, 1)
            feasible = reshape(logical(study.is_feasible(criterion, :)), 1, []);
            for p = 1:size(pairs, 1)
                x = reshape(study.metrics(criterion, :, pairs(p, 1)), 1, []);
                y = reshape(study.metrics(criterion, :, pairs(p, 2)), 1, []);
                valid = feasible & isfinite(x) & isfinite(y);
                if nnz(valid) < 3, continue; end
                if pairs(p, 1) == 1, x = -x; end
                if pairs(p, 2) == 1, y = -y; end
                rho = local_spearman(x(valid), y(valid));
                if isfinite(rho)
                    rho_by_pair{p}(end + 1) = rho;
                end
            end
        end
    end
    for p = 1:size(pairs, 1)
        rho = rho_by_pair{p};
        stats{n,p} = struct('median', median(rho), 'minimum', min(rho), ...
            'maximum', max(rho), 'positive', nnz(rho > 1e-12), ...
            'negative', nnz(rho < -1e-12), 'zero', nnz(abs(rho) <= 1e-12), ...
            'count', numel(rho));
    end
end

pair_name = strings(size(pairs, 1), 1);
anytown_summary = strings(size(pairs, 1), 1);
anytown_signs = strings(size(pairs, 1), 1);
balerma_summary = strings(size(pairs, 1), 1);
balerma_signs = strings(size(pairs, 1), 1);
for p = 1:size(pairs, 1)
    pair_name(p) = records{p}.pair;
    a = stats{1,p}; b = stats{2,p};
    anytown_summary(p) = sprintf('%+.2f [%+.2f,%+.2f]', ...
        a.median, a.minimum, a.maximum);
    balerma_summary(p) = sprintf('%+.2f [%+.2f,%+.2f]', ...
        b.median, b.minimum, b.maximum);
    anytown_signs(p) = sprintf('%d/%d/%d (N=%d)', ...
        a.positive, a.negative, a.zero, a.count);
    balerma_signs(p) = sprintf('%d/%d/%d (N=%d)', ...
        b.positive, b.negative, b.zero, b.count);
end
rows = table(pair_name, anytown_summary, anytown_signs, ...
    balerma_summary, balerma_signs, 'VariableNames', ...
    {'MetricPair','AnytownMedianRange','AnytownPositiveNegativeZero', ...
    'BalermaMedianRange','BalermaPositiveNegativeZero'});
end

function study = local_find_study(loaded, objective)
fields = fieldnames(loaded);
for i = 1:numel(fields)
    candidate = loaded.(fields{i});
    if isstruct(candidate) && isfield(candidate, 'metrics') && ...
            isfield(candidate, 'criterion_keys') && isfield(candidate, 'objective') && ...
            strcmp(candidate.objective, objective)
        study = candidate;
        return;
    end
end
error('Ranking study for objective %s was not found.', objective);
end

function rho = local_spearman(x, y)
rx = local_tied_rank(x(:));
ry = local_tied_rank(y(:));
rx = rx - mean(rx);
ry = ry - mean(ry);
denominator = sqrt(sum(rx.^2) * sum(ry.^2));
if denominator == 0
    rho = NaN;
else
    rho = sum(rx .* ry) / denominator;
end
end

function ranks = local_tied_rank(values)
[sorted_values, order] = sort(values);
ranks_sorted = zeros(size(values));
i = 1;
while i <= numel(values)
    j = i;
    while j < numel(values) && sorted_values(j + 1) == sorted_values(i)
        j = j + 1;
    end
    ranks_sorted(i:j) = mean(i:j);
    i = j + 1;
end
ranks = zeros(size(values));
ranks(order) = ranks_sorted;
end

function map = local_diverging_map(n)
anchors = [0.72 0.10 0.12; 1.00 1.00 1.00; 0.08 0.55 0.25];
x = [0 0.5 1];
xi = linspace(0, 1, n);
map = [interp1(x, anchors(:,1), xi)', ...
    interp1(x, anchors(:,2), xi)', interp1(x, anchors(:,3), xi)'];
end

function rows = local_cross_effect_table(cross_effects, network_ids, ...
        objective_labels, metric_labels)
network = strings(50, 1); objective = strings(50, 1); metric = strings(50, 1);
raw = zeros(50, 1); beneficial = zeros(50, 1); color = zeros(50, 1);
r = 0;
for n = 1:2
    for i = 1:5
        for j = 1:5
            r = r + 1;
            network(r) = network_ids{n}; objective(r) = objective_labels{i};
            metric(r) = metric_labels{j};
            raw(r) = cross_effects{n}.raw_change_percent(i,j);
            beneficial(r) = cross_effects{n}.beneficial_change_percent(i,j);
            color(r) = cross_effects{n}.column_normalized_color(i,j);
        end
    end
end
rows = table(network, objective, metric, raw, beneficial, color, ...
    'VariableNames', {'Network','OptimizedObjective','EvaluatedMetric', ...
    'RawChangePercent','BeneficialChangePercent','ColumnNormalizedColor'});
end

function local_write_latex_table(rows, output_file)
fid = fopen(output_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%% Generated by make_objective_relationship_summary.m\n');
fprintf(fid, '\\begin{table}[t]\n');
fprintf(fid, '\\caption{Rank association of paired performance metrics along the 20 available nested ranking trajectories in each network (four optimized objectives times five ranking criteria). $\\rho^*$ is Spearman''s rank correlation after reversing the sign of cost, so positive values denote joint movement in the desirable direction. Entries give median [minimum, maximum]; $+/-/0$ counts trajectories by correlation sign. Undefined constant trajectories are omitted.}\n');
fprintf(fid, '\\label{tab:ranking_metric_correlations}\n');
fprintf(fid, '\\centering\\scriptsize\\renewcommand{\\arraystretch}{1.08}\n');
fprintf(fid, '\\begin{tabular}{lcccc}\\toprule\n');
fprintf(fid, 'Metric pair & Anytown $\\rho^*$ & $+/-/0$ & Balerma $\\rho^*$ & $+/-/0$ \\\\\n');
fprintf(fid, '\\midrule\n');
for i = 1:height(rows)
    pair = strrep(char(rows.MetricPair(i)), ' -- ', ' / ');
    pair = strrep(pair, 'Cl concentration', 'Cl conc.');
    pair = strrep(pair, 'Hydraulic entropy', 'Hyd. entropy');
    pair = strrep(pair, 'Chlorine entropy', 'Cl entropy');
    a_sign = regexp(char(rows.AnytownPositiveNegativeZero(i)), '^[^ ]+', ...
        'match', 'once');
    b_sign = regexp(char(rows.BalermaPositiveNegativeZero(i)), '^[^ ]+', ...
        'match', 'once');
    fprintf(fid, '%s & %s & %s & %s & %s \\\\\n', pair, ...
        char(rows.AnytownMedianRange(i)), a_sign, ...
        char(rows.BalermaMedianRange(i)), b_sign);
end
fprintf(fid, '\\bottomrule\\end{tabular}\n');
fprintf(fid, '\\end{table}\n');
end
