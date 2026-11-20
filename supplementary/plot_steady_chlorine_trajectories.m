function plot_steady_chlorine_trajectories(results_dir, output_dir)
%PLOT_STEADY_CHLORINE_TRAJECTORIES EPANET buildup and STACI steady states.
% Use the current branch-hop design for each network. Results are stored in
% supplementary/results/current_chlorine, relative to this file.
% Usage: plot_steady_chlorine_trajectories;
%        plot_steady_chlorine_trajectories(results_dir, output_dir)

root = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(results_dir)
    results_dir = fullfile(root, 'results', 'current_chlorine');
end
if nargin < 2 || isempty(output_dir), output_dir = results_dir; end
if ~isfolder(output_dir), mkdir(output_dir); end

groups = { ...
    'tanyimboh_templeman', {'4','6','5'}, 4, ...
        '(a) Tanyimboh--Templeman'; ...
    'anytown', {'20','100','170'}, 10, ...
        '(b) Anytown: overview'; ...
    'anytown', {'140','80','90'}, 65, ...
        '(c) Anytown: distant consumers'; ...
    'balerma', {'179001','246','422'}, 25, ...
        '(d) Balerma: overview'; ...
    'balerma', {'337','72','336'}, 80, ...
        '(e) Balerma: distant consumers'};
colors = [0.00 0.38 0.74; 0.85 0.33 0.10; 0.24 0.62 0.28];
convergence = readtable(fullfile(results_dir, 'convergence.csv'), ...
    'TextType', 'string');

fig = figure('Color', 'w', 'Units', 'inches', ...
    'Position', [1 1 6.4 8.6]);
layout = tiledlayout(fig, 5, 1, 'Padding', 'compact', ...
    'TileSpacing', 'compact');
for group = 1:size(groups, 1)
    network = groups{group, 1};
    nodes = groups{group, 2};
    xmax = groups{group, 3};
    folder = fullfile(results_dir, network, ...
        'branch_hop_weighted_entropy');
    trajectory_path = fullfile(folder, 'trajectory.csv');
    file_id = fopen(trajectory_path, 'r');
    assert(file_id > 0, 'Cannot read %s', trajectory_path);
    columns = split(string(fgetl(file_id)), ',');
    fclose(file_id);
    data = readmatrix(trajectory_path, 'NumHeaderLines', 1);
    steady = jsondecode(fileread(fullfile(folder, 'steady.json')));
    time = data(:, 1);
    ax = nexttile(layout);
    hold(ax, 'on');
    curves = gobjects(1, 3);
    for j = 1:3
        id = nodes{j};
        col = find(columns == string(id), 1);
        assert(isscalar(col), 'Missing EPANET node %s in %s', id, network);
        curves(j) = plot(ax, time, data(:, col), '-', ...
            'Color', colors(j, :), 'LineWidth', 1.45);
        steady_value = steady.(matlab.lang.makeValidName(id));
        yline(ax, steady_value, '--', ...
            'Color', colors(j, :), 'LineWidth', 1.10, ...
            'HandleVisibility', 'off');
    end
    match = string(convergence.network) == string(network);
    assert(nnz(match) == 1, 'Missing convergence time for %s', network);
    convergence_h = convergence.convergence_h(match);
    if convergence_h <= xmax
        xline(ax, convergence_h, ':', ...
            'Color', [0.35 0.35 0.35], 'LineWidth', 1.0, ...
            'HandleVisibility', 'off');
    end
    title(ax, groups{group, 4}, 'FontSize', 11, 'FontWeight', 'normal');
    xlim(ax, [0 xmax]); ylim(ax, [0 1.04]);
    ylabel(ax, 'Cl [mg/L]', 'FontSize', 11);
    xlabel(ax, 'Time [h]', 'FontSize', 11);
    ax.FontSize = 11; ax.LineWidth = 0.8;
    grid(ax, 'on');
    location = 'southeast';
    if group == 5, location = 'northeast'; end
    legend(ax, curves, compose('Node %s', string(nodes)), ...
        'Location', location, 'Orientation', 'horizontal', ...
        'FontSize', 11, 'Box', 'off');
end
exportgraphics(fig, fullfile(output_dir, 'steady_chlorine_trajectories.png'), ...
    'Resolution', 300);
exportgraphics(fig, fullfile(output_dir, 'steady_chlorine_trajectories.svg'), ...
    'ContentType', 'vector');
close(fig);
end
