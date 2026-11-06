function output_files = plot_ranking_objective_matrix(cfg, cost_study, entropy_study, ~)
%PLOT_RANKING_OBJECTIVE_MATRIX Plot two ranked-subset optimization series.
% Values are percentage changes from the original, unoptimized network.

colors = lines(numel(cost_study.criterion_labels));
markers = {'o','s','^','d','v'};
fig = figure('Color','w','Position',[100 50 1400 1780]);
t = tiledlayout(fig, 5, 2, 'TileSpacing','loose','Padding','compact');
x_percent = 100 * cost_study.k / numel(cfg.design_link_ids);

entropy_metric='hydraulic_entropy';
if strcmp(string(entropy_study.objective),'branch_hop_weighted_entropy')
    entropy_metric='branch_hop_weighted_entropy';
end
left_order = {'cost',entropy_metric,'chlorine_concentration', ...
    'chlorine_entropy','todini'};
right_order = {entropy_metric,'cost','chlorine_concentration', ...
    'chlorine_entropy','todini'};
labels = struct( ...
    'cost','Cost (%) (\leftarrow better)', ...
    'hydraulic_entropy','Hyd. entropy (%) (better \rightarrow)', ...
    'branch_hop_weighted_entropy','Branch-hop entropy (%) (better \rightarrow)', ...
    'chlorine_concentration','Cl concentration (%) (better \rightarrow)', ...
    'chlorine_entropy','Cl entropy (%) (better \rightarrow)', ...
    'todini','Todini (%) (better \rightarrow)');

first_axis = gobjects(1);
for row = 1:5
    ax_left = nexttile(t);
    left_values = relative_metric(cost_study, left_order{row});
    left_handles = plot_panel(ax_left, x_percent, left_values, ...
        labels.(left_order{row}), colors, markers, ...
        reference_is_infeasible(cost_study));
    if row == 1
        first_axis = ax_left;
        first_handles = left_handles;
        title(ax_left,'Optimized for cost (minimize)', ...
            'FontSize',15,'FontWeight','bold');
    elseif row == 2
        title(ax_left,'Other objectives evaluated on these designs', ...
            'FontSize',13,'FontWeight','normal','FontAngle','italic');
    end

    ax_right = nexttile(t);
    right_values = relative_metric(entropy_study, right_order{row});
    plot_panel(ax_right, x_percent, right_values, labels.(right_order{row}), ...
        colors, markers, reference_is_infeasible(entropy_study));
    if row == 1
        if strcmp(entropy_metric,'branch_hop_weighted_entropy')
            objective_title='Optimized for branch-hop entropy (maximize)';
        else
            objective_title='Optimized for hydraulic entropy (maximize)';
        end
        title(ax_right,objective_title,'FontSize',15, ...
            'FontWeight','bold');
    elseif row == 2
        title(ax_right,'Other objectives evaluated on these designs', ...
            'FontSize',13,'FontWeight','normal','FontAngle','italic');
    end
end

lgd = legend(first_axis, first_handles, cost_study.criterion_labels, ...
    'Orientation','horizontal','NumColumns',5,'FontSize',14,'Box','off');
lgd.Layout.Tile = 'north';
xlabel(t, 'Pipes released for optimization (%)', 'FontSize', 18);

if ~exist(cfg.figures_dir, 'dir'), mkdir(cfg.figures_dir); end
basename = 'figure9_ranking_objectives';
if isfield(cfg, 'ranking') && isfield(cfg.ranking, 'figure_basename')
    basename = cfg.ranking.figure_basename;
end
png_file = fullfile(cfg.figures_dir, [basename '.png']);
svg_file = fullfile(cfg.figures_dir, [basename '.svg']);
exportgraphics(fig, png_file, 'Resolution', cfg.plot.resolution);
exportgraphics(fig, svg_file, 'ContentType','vector');
close(fig);
output_files = {png_file, svg_file};
end

function values = relative_metric(study, metric_name)
metric_index = find(strcmp(study.metric_names, metric_name), 1);
values = study.metrics(:, :, metric_index);
values = reshape(values, size(study.metrics, 1), size(study.metrics, 2));
original = study.original_metrics.(metric_name);
values = 100 * (values / original - 1);
end

function infeasible = reference_is_infeasible(study)
infeasible = isfield(study,'original_constraint_violation') && ...
    study.original_constraint_violation > 0;
end

function handles = plot_panel(ax, x_percent, values, y_label, colors, markers, reference_infeasible)
hold(ax, 'on');
handles = gobjects(size(values, 1), 1);
for q = 1:size(values, 1)
    series = values(q, :);
    if reference_infeasible, series(1) = NaN; end
    handles(q) = plot(ax, x_percent, series, '-', 'Color', colors(q, :), ...
        'Marker', markers{q}, 'LineWidth', 1.6, 'MarkerSize', 5.2, ...
        'MarkerFaceColor','w');
end
if x_percent(1) == 0 && isfinite(values(1, 1))
    reference_marker = 'ko';
    if reference_infeasible, reference_marker = 'ks'; end
    plot(ax, 0, values(1, 1), reference_marker, 'MarkerFaceColor','k', ...
        'MarkerSize',5.5,'HandleVisibility','off');
end
grid(ax, 'on'); box(ax, 'on');
x_max = max(x_percent);
x_padding = max(0.02 * x_max, eps);
xlim(ax, [-x_padding, x_max + x_padding]);
if x_max >= 80
    xticks(ax, 0:25:100);
else
    rounded_upper = ceil(x_max / 2) * 2;
    xlim(ax, [-x_padding, rounded_upper + x_padding]);
    xticks(ax, 0:2:rounded_upper);
    xtickformat(ax, '%.0f');
end
limits = ylim(ax);
padding = max(0.04 * diff(limits), 1e-6);
ylim(ax, limits + [-padding, padding]);
ytickformat(ax, '%.3g');
ylabel(ax, y_label, 'FontSize', 13);
ax.FontSize = 14;
end
