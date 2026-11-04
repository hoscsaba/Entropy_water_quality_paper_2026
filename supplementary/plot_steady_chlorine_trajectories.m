function plot_steady_chlorine_trajectories(results_dir)
%PLOT_STEADY_CHLORINE_TRAJECTORIES EPANET history and STACI asymptotes.
if nargin < 1 || strlength(string(results_dir)) == 0
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
end
summary = readtable(fullfile(results_dir, 'summary.csv'), 'TextType', 'string');
networks = ["tanyimboh_templeman", "anytown", "balerma"];
names = ["Tanyimboh–Templeman", "Anytown", "Balerma"];
colors = [0.00 0.38 0.74; 0.85 0.33 0.10; 0.24 0.62 0.28];
fig = figure('Color', 'w', 'Position', [80 80 1150 1040]);
layout = tiledlayout(fig, 3, 1, 'Padding', 'compact', ...
    'TileSpacing', 'compact');
for k = 1:numel(networks)
    row = summary(summary.network == networks(k) & ...
                  summary.design == "original", :);
    assert(height(row) == 1, 'Missing original network comparison');
    folder = fullfile(results_dir, networks(k), 'original');
    trajectory = readmatrix(fullfile(folder, 'trajectory.csv'), ...
        'NumHeaderLines', 1);
    steady = jsondecode(fileread(fullfile(folder, 'steady.json')));
    ids = split(row.representative_nodes, ',');
    max_hour = min(max(row.convergence_h + 24, 26), row.duration_h);
    hours = trajectory(:, 1);
    visible = hours <= max_hour;
    ax = nexttile(layout);
    hold(ax, 'on');
    for j = 1:numel(ids)
        id = char(ids(j));
        concentration = trajectory(:, j + 1);
        plot(ax, hours(visible), concentration(visible), ...
            '-', 'Color', colors(j, :), 'LineWidth', 1.9, ...
            'DisplayName', sprintf('EPANET %s', id));
        steady_value = steady.(matlab.lang.makeValidName(id));
        yline(ax, steady_value, '--', 'Color', colors(j, :), ...
            'LineWidth', 1.3, 'DisplayName', sprintf('STACI %s', id));
    end
    xline(ax, row.convergence_h, ':', 'Color', [0.25 0.25 0.25], ...
        'LineWidth', 1.1, 'HandleVisibility', 'off');
    title(ax, names(k), 'FontSize', 16, 'FontWeight', 'normal');
    ylabel(ax, 'Chlorine [mg/L]', 'FontSize', 13);
    xlabel(ax, 'Time [h]', 'FontSize', 13);
    ylim(ax, [-0.04 1.05]);
    xlim(ax, [0 max_hour]);
    grid(ax, 'on');
    ax.FontSize = 12;
    % A small in-panel key is retained for every network. MATLAB may keep
    % only one axes legend when these axes are exported as a tiled layout.
    for j = 1:numel(ids)
        text(ax, 0.72 * max_hour, 0.06 + 0.07 * (j - 1), ...
            sprintf('Node %s', ids(j)), 'Color', colors(j, :), ...
            'FontSize', 10, 'FontWeight', 'bold');
    end
end
exportgraphics(fig, fullfile(results_dir, 'steady_chlorine_trajectories.png'), ...
    'Resolution', 300);
exportgraphics(fig, fullfile(results_dir, 'steady_chlorine_trajectories.svg'), ...
    'ContentType', 'vector');
close(fig);
end
