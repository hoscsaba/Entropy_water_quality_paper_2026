function plot_new_chlorine_designs(output_dir)
%PLOT_NEW_CHLORINE_DESIGNS Six newly searched fixed-load STACI designs.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
if nargin < 1 || strlength(string(output_dir)) == 0
    output_dir = fullfile(root, 'supplementary', 'results');
end
if ~isfolder(output_dir), mkdir(output_dir); end
networks = ["tanyimboh_templeman", "anytown", "balerma"];
labels = ["Tanyimboh–Templeman", "Anytown", "Balerma"];
objectives = ["chlorine_concentration", "chlorine_entropy"];
titles = ["Concentration", "Chlorine entropy"];
fig = figure('Color', 'w', 'Position', [60 60 1550 1700]);
layout = tiledlayout(fig, 3, 2, 'Padding', 'compact', ...
    'TileSpacing', 'compact');
colormap(fig, turbo(256));
for row = 1:numel(networks)
    network_dir = char(fullfile(root, 'networks', networks(row)));
    addpath(network_dir);
    cfg = network_config(network_dir);
    wdn.setup_toolkit(cfg);
    [ep, model] = wdn.open_network(cfg);
    ep_cleanup = onCleanup(@() ep.unload());
    coordinates = ep.getNodeCoordinates();
    xx = cell2mat(coordinates(:, 1));
    yy = cell2mat(coordinates(:, 2));
    endpoints = double(ep.getLinkNodesIndex());
    for column = 1:numel(objectives)
        saved = load(fullfile(network_dir, 'results_staci_constrained', ...
            objectives(column) + ".mat"), 'result');
        record = saved.result;
        full_diameters = model.original_full_diameters(:);
        full_diameters(model.design_link_indices) = ...
            record.design_diameters(:);
        [found, nidx] = ismember(model.node_ids, ...
            string(record.metrics.node_ids));
        assert(all(found), 'STACI/EPANET node-order mismatch');
        chlorine = double(record.metrics.chlorine(nidx));
        ax = nexttile(layout);
        hold(ax, 'on');
        for link = 1:numel(full_diameters)
            if ismember(link, model.design_link_indices)
                fraction = (full_diameters(link) - cfg.minimum_diameter) / ...
                    (cfg.maximum_diameter - cfg.minimum_diameter);
                line_width = 0.4 + 4.0 * min(max(fraction, 0), 1);
                if full_diameters(link) <= cfg.minimum_diameter * 1.001
                    line_style = '--';
                else
                    line_style = '-';
                end
            else
                line_width = 1.6;
                line_style = '-';
            end
            plot(ax, xx(endpoints(link, :)), yy(endpoints(link, :)), ...
                'k', 'LineWidth', line_width, 'LineStyle', line_style);
        end
        node_marker = 35;
        if row == 3, node_marker = 10; end
        scatter(ax, xx, yy, node_marker, chlorine, 'filled', ...
            'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.4);
        clim(ax, [0 1]);
        axis(ax, 'equal');
        axis(ax, 'off');
        title(ax, labels(row) + " — " + titles(column), ...
            'FontSize', 17, 'FontWeight', 'normal');
    end
    clear ep_cleanup ep
end
bar = colorbar;
bar.Layout.Tile = 'east';
bar.Label.String = 'Steady chlorine [mg/L]';
bar.FontSize = 13;
exportgraphics(fig, fullfile(output_dir, 'new_staci_chlorine_designs.png'), ...
    'Resolution', 300);
exportgraphics(fig, fullfile(output_dir, 'new_staci_chlorine_designs.svg'), ...
    'ContentType', 'vector');
close(fig);
end
