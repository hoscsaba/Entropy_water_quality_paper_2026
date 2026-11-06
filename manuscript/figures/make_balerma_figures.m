function output_files = make_balerma_figures(result_dir_override,figure_dir_override)
%MAKE_BALERMA_FIGURES Rebuild the six-panel Balerma objective figure.
%   This function reads validated MAT results and does not optimize.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir,'results_staci');
cfg.figures_dir = fullfile(network_dir,'figures_staci');
publish=true;
if nargin>=1 && ~isempty(result_dir_override)
    cfg.results_dir=char(result_dir_override);
    publish=false;
end
if nargin>=2 && ~isempty(figure_dir_override)
    cfg.figures_dir=char(figure_dir_override);
end
wdn.setup_toolkit(cfg);

result_names = {'cost','hydraulic_entropy', ...
    'branch_hop_weighted_entropy_rank45','chlorine_concentration', ...
    'chlorine_entropy','todini'};
panel_titles = {'(a) Cost','(b) Flow entropy', ...
    '(c) Branch-hop entropy (45 pipes)','(d) Chlorine concentration', ...
    '(e) Chlorine entropy','(f) Todini index'};

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
coordinates = d.getNodeCoordinates();
geometry.node_x = cell2mat(coordinates(:, 1));
geometry.node_y = cell2mat(coordinates(:, 2));
geometry.link_nodes = d.getLinkNodesIndex;
geometry.node_types = d.getNodeTypeIndex;
geometry.node_ids = string(d.getNodeNameID);

data = cell(size(result_names));
all_pressure = [];
for index = 1:numel(result_names)
    saved = load(fullfile(cfg.results_dir, [result_names{index} '.mat']));
    item = geometry;
    if strcmp(result_names{index}, 'baseline')
        record = saved.baseline;
    else
        record = saved.result;
        if record.max_constraint_violation > cfg.ga.constraint_tolerance
            error('balerma:InvalidResult', '%s is not pressure-feasible.', ...
                result_names{index});
        end
    end
    if ~isequal(string(record.full_link_ids(:)), string(model.link_ids(:)))
        error('balerma:LinkOrderMismatch', ...
            '%s link order does not match the INP file.', result_names{index});
    end
    item.diameters = double(record.full_diameters(:));
    [found_nodes,node_order] = ismember( ...
        geometry.node_ids,string(record.metrics.node_ids(:)));
    assert(all(found_nodes),'Balerma STACI node ID mismatch');
    item.pressure = double(record.metrics.pressures(node_order));
    item.chlorine = double(record.metrics.chlorine(node_order));
    % Reservoir boundary nodes carry fixed total head and are drawn with
    % separate blue squares. Scale pressure colors from demand junctions.
    pressure_nodes = geometry.node_types(:) ~= 1 & isfinite(item.pressure(:));
    all_pressure = [all_pressure; item.pressure(pressure_nodes)]; %#ok<AGROW>
    data{index} = item;
end

x = data{1}.node_x;
y = data{1}.node_y;
x_padding = 0.025 * max(max(x) - min(x), 1);
y_padding = 0.025 * max(max(y) - min(y), 1);
x_limits = [min(x) - x_padding, max(x) + x_padding];
y_limits = [min(y) - y_padding, max(y) + y_padding];
pressure_limits = [min(0, floor(min(all_pressure) / 5) * 5), ...
    ceil(max(all_pressure) / 5) * 5];

fig = figure('Color', 'w', 'Position', [80 40 1900 1320]);
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
colormap(fig, jet(256));
for index = 1:numel(data)
    ax = nexttile(layout);
    draw_network(ax, data{index}, x_limits, y_limits, pressure_limits, ...
        'pressure');
    title(ax, panel_titles{index}, 'FontSize', 18, 'FontWeight', 'normal');
end
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.FontSize = 15;
ylabel(cb, 'Pressure [m]', 'FontSize', 17);

if ~isfolder(cfg.figures_dir), mkdir(cfg.figures_dir); end
png_file = fullfile(cfg.figures_dir, 'figure10_balerma_objectives.png');
svg_file = fullfile(cfg.figures_dir, 'figure10_balerma_objectives.svg');
exportgraphics(fig, png_file, 'Resolution', cfg.plot.resolution);
exportgraphics(fig, svg_file, 'ContentType', 'image', 'Resolution', 300);
close(fig);

generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if publish
    if ~isfolder(generated_dir), mkdir(generated_dir); end
    copyfile(png_file, fullfile(generated_dir, ...
        'figure10_balerma_objectives.png'), 'f');
    copyfile(svg_file, fullfile(generated_dir, ...
        'figure10_balerma_objectives.svg'), 'f');
end

% A matching six-panel water-quality map uses the same diameter encoding.
fig = figure('Color','w','Position',[80 40 1900 1320]);
layout = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
colormap(fig,jet(256));
for index=1:numel(data)
    ax=nexttile(layout);
    draw_network(ax,data{index},x_limits,y_limits,[0 1],'chlorine');
    title(ax,panel_titles{index},'FontSize',18,'FontWeight','normal');
end
cb=colorbar(ax);
cb.Layout.Tile='east';
cb.FontSize=15;
ylabel(cb,'Chlorine [mg/L]','FontSize',17);
cl_png=fullfile(cfg.figures_dir,'figure14_balerma_chlorine.png');
cl_svg=fullfile(cfg.figures_dir,'figure14_balerma_chlorine.svg');
exportgraphics(fig,cl_png,'Resolution',cfg.plot.resolution);
exportgraphics(fig,cl_svg,'ContentType','image','Resolution',300);
close(fig);
if publish
    copyfile(cl_png,fullfile(generated_dir,'figure14_balerma_chlorine.png'),'f');
    copyfile(cl_svg,fullfile(generated_dir,'figure14_balerma_chlorine.svg'),'f');
end
output_files = {png_file, svg_file, cl_png, cl_svg};
end

function draw_network(ax, item, x_limits, y_limits, color_limits, color_metric)
hold(ax, 'on');
for link = 1:size(item.link_nodes, 1)
    diameter = item.diameters(link);
    line_width = 0.35 + 3.65 * min(max(diameter / 500, 0), 1);
    line_style = '-';
    if diameter < 50, line_style = '--'; end
    plot(ax, item.node_x(item.link_nodes(link, :)), ...
        item.node_y(item.link_nodes(link, :)), 'Color', [0.08 0.08 0.08], ...
        'LineWidth', line_width, 'LineStyle', line_style);
end
scatter(ax, item.node_x, item.node_y, 15, item.(color_metric), 'filled', ...
    'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.35);
reservoirs = find(item.node_types == 1);
scatter(ax, item.node_x(reservoirs), item.node_y(reservoirs), 70, ...
    [0.10 0.28 0.75], 's', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
axis(ax, 'equal');
xlim(ax, x_limits);
ylim(ax, y_limits);
clim(ax, color_limits);
axis(ax, 'off');
end
