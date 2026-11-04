function make_anytown_schematic
%MAKE_ANYTOWN_SCHEMATIC Plot topology and explicitly mark hydraulic equipment.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
coords = d.getNodeCoordinates;
node_x = cell2mat(coords(:,1));
node_y = cell2mat(coords(:,2));
links = double(d.getLinkNodesIndex);

fig = figure('Color', 'w', 'Position', [100 100 1150 720]);
ax = axes(fig); hold(ax, 'on');
for k = 1:size(links, 1)
    if ismember(k, model.entropy_excluded_link_indices)
        color = [0.35 0.35 0.35];
        style = '--';
        width = 1.7;
    else
        color = [0.15 0.15 0.15];
        style = '-';
        width = 1.4;
    end
    plot(ax, node_x(links(k,:)), node_y(links(k,:)), ...
        'Color', color, 'LineStyle', style, 'LineWidth', width);
end

scatter(ax, node_x, node_y, 70, 'w', 'filled', ...
    'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
for n = 1:numel(model.node_ids)
    text(ax, node_x(n), node_y(n) + 135, char(model.node_ids(n)), ...
        'FontSize', 12, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'BackgroundColor', 'w', 'Margin', 0.5);
end

wdn.mark_hydraulic_equipment(ax, node_x, node_y, links, model, cfg, 1.25);

axis(ax, 'equal');
x_padding = 0.08 * (max(node_x) - min(node_x));
y_padding = 0.10 * (max(node_y) - min(node_y));
xlim(ax, [min(node_x)-x_padding, max(node_x)+x_padding]);
ylim(ax, [min(node_y)-y_padding, max(node_y)+y_padding]);
axis(ax, 'off');

exportgraphics(fig, fullfile(cfg.figures_dir, 'anytown_schematic.png'), ...
    'Resolution', 600);
exportgraphics(fig, fullfile(cfg.figures_dir, 'anytown_schematic.svg'), ...
    'ContentType', 'vector');
close(fig);

generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end
copyfile(fullfile(cfg.figures_dir, 'anytown_schematic.png'), ...
    fullfile(generated_dir, 'anytown_schematic.png'), 'f');
copyfile(fullfile(cfg.figures_dir, 'anytown_schematic.svg'), ...
    fullfile(generated_dir, 'anytown_schematic.svg'), 'f');
clear cleanup
end
