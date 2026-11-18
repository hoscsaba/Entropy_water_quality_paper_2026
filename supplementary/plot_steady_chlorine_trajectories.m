function plot_steady_chlorine_trajectories(results_dir,anytown_results_dir)
%PLOT_STEADY_CHLORINE_TRAJECTORIES EPANET history and STACI asymptotes.
if nargin < 1 || strlength(string(results_dir)) == 0
    results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
end
summary = readtable(fullfile(results_dir, 'summary.csv'), 'TextType', 'string');
if nargin<2 || isempty(anytown_results_dir)
    anytown_results_dir=results_dir;
end
networks = ["tanyimboh_templeman", "anytown", "anytown", ...
    "balerma", "balerma"];
names = ["Tanyimboh–Templeman", "Anytown", ...
    "Anytown: distant nodes", "Balerma", "Balerma: distant nodes"];
distal = [false false true false true];
colors = [0.00 0.38 0.74; 0.85 0.33 0.10; 0.24 0.62 0.28];
fig = figure('Color', 'w', 'Position', [80 80 1150 1400]);
layout = tiledlayout(fig, 5, 1, 'Padding', 'compact', ...
    'TileSpacing', 'compact');
for k = 1:numel(networks)
    current_results=results_dir;
    current_summary=summary;
    if networks(k)=="anytown"
        current_results=anytown_results_dir;
        if ~strcmp(string(anytown_results_dir),string(results_dir))
            current_summary=readtable(fullfile(anytown_results_dir, ...
                'summary.csv'),'TextType','string');
        end
    end
    row = current_summary(current_summary.network == networks(k) & ...
                  current_summary.design == "original", :);
    assert(height(row) == 1, 'Missing original network comparison');
    folder = fullfile(current_results, networks(k), 'original');
    if distal(k)
        trajectory_file='trajectory_distal.csv';
        if networks(k)=="anytown"
            ids=["75"; "115"; "140"];
            max_hour=48;
        else
            ids=["58"; "213"; "235"];
            max_hour=8;
        end
    else
        trajectory_file='trajectory.csv';
        ids=split(row.representative_nodes, ',');
        max_hour=min(max(row.convergence_h + 24, 26), row.duration_h);
    end
    trajectory = readmatrix(fullfile(folder, trajectory_file), ...
        'NumHeaderLines', 1);
    steady = jsondecode(fileread(fullfile(folder, 'steady.json')));
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
    if row.convergence_h<=max_hour
        xline(ax, row.convergence_h, ':', 'Color', [0.25 0.25 0.25], ...
            'LineWidth', 1.1, 'HandleVisibility', 'off');
    end
    title(ax, names(k), 'FontSize', 20, 'FontWeight', 'normal');
    ylabel(ax, 'Chlorine [mg/L]', 'FontSize', 18);
    xlabel(ax, 'Time [h]', 'FontSize', 18);
    ylim(ax, [-0.04 1.05]);
    xlim(ax, [0 max_hour]);
    grid(ax, 'on');
    ax.FontSize = 18;
    % A small in-panel key is retained for every network. MATLAB may keep
    % only one axes legend when these axes are exported as a tiled layout.
    label_x=0.72*max_hour;
    if networks(k)=="anytown" && ~distal(k)
        label_x=0.62*max_hour; % clear the 92-h convergence marker
    end
    for j = 1:numel(ids)
        text(ax, label_x, 0.10 + 0.13 * (j - 1), ...
            sprintf('Node %s', ids(j)), 'Color', colors(j, :), ...
            'FontSize', 17, 'FontWeight', 'bold');
    end
end
exportgraphics(fig, fullfile(results_dir, 'steady_chlorine_trajectories.png'), ...
    'Resolution', 300);
exportgraphics(fig, fullfile(results_dir, 'steady_chlorine_trajectories.svg'), ...
    'ContentType', 'vector');
close(fig);
end
