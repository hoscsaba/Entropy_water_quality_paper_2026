function output_files = make_balerma_schematic
%MAKE_BALERMA_SCHEMATIC Draw the Balerma input topology and reservoirs.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root, '-begin');
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir, '-begin');
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
coordinates = d.getNodeCoordinates();
x = cell2mat(coordinates(:, 1));
y = cell2mat(coordinates(:, 2));
links = double(d.getLinkNodesIndex);
node_types = double(d.getNodeTypeIndex);

fig = figure('Color', 'w', 'Position', [80 50 1350 900]);
ax = axes(fig);
hold(ax, 'on');
for k = 1:size(links, 1)
    plot(ax, x(links(k, :)), y(links(k, :)), '-', ...
        'Color', [0.35 0.35 0.35], 'LineWidth', 0.55);
end
scatter(ax, x, y, 8, [0.12 0.12 0.12], 'filled');
reservoirs = find(node_types == 1);
scatter(ax, x(reservoirs), y(reservoirs), 82, [0.10 0.32 0.80], ...
    's', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.0);
axis(ax, 'equal');
axis(ax, 'off');
title(ax, 'Balerma benchmark network', 'FontWeight', 'normal', 'FontSize', 14);

output_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(output_dir), mkdir(output_dir); end
png_file = fullfile(output_dir, 'balerma.png');
svg_file = fullfile(output_dir, 'balerma.svg');
exportgraphics(fig, png_file, 'Resolution', 600);
exportgraphics(fig, svg_file, 'ContentType', 'vector');
close(fig);
output_files = {png_file, svg_file};
clear cleanup
end
