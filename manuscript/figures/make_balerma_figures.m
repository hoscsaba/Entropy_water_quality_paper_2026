function output_files = make_balerma_figures(result_dir_override,figure_dir_override)
%MAKE_BALERMA_FIGURES Rebuild the six-panel Balerma objective figure.
%   This function reads validated MAT results and does not optimize.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
% Default to the released R38-anchor design set. Older Balerma studies can
% still be drawn by passing their result and figure directories explicitly.
cfg = network_config_r38_anchor(network_dir);
cfg.results_dir = fullfile(network_dir, ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
cfg.figures_dir = fullfile(network_dir,'figures_staci_r38_anchor_v1');
publish=true;
if nargin>=1 && ~isempty(result_dir_override)
    cfg.results_dir=char(result_dir_override);
    publish=false;
end
if nargin>=2 && ~isempty(figure_dir_override)
    cfg.figures_dir=char(figure_dir_override);
end
r38_anchor=contains(string(cfg.results_dir),'r38_anchor');
wdn.setup_toolkit(cfg);

common_bound=isfile(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'));
if common_bound
    result_names={'cost','hydraulic_entropy', ...
        'branch_hop_weighted_entropy','chlorine_concentration', ...
        'chlorine_entropy','todini'};
    panel_titles={'(a) Cost','(b) Flow entropy', ...
        '(c) Branch-hop entropy','(d) Chlorine concentration', ...
        '(e) Chlorine entropy','(f) Todini index'};
    layout_shape=[3,2];
    diameter_reference=1625.6;
    dashed_limit=25.4; % 1 in in the common-bound study
    filename_suffix='_common_3x2';
else
    result_names={'cost','hydraulic_entropy', ...
        'branch_hop_weighted_entropy_rank45','chlorine_concentration', ...
        'chlorine_entropy','todini'};
    panel_titles={'(a) Cost','(b) Flow entropy', ...
        '(c) Branch-hop entropy (45 pipes)','(d) Chlorine concentration', ...
        '(e) Chlorine entropy','(f) Todini index'};
    layout_shape=[2,3];
    diameter_reference=500;
    dashed_limit=50;
    filename_suffix='';
end
if r38_anchor
    filename_suffix='_r38_anchor_3x2';
end

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
coordinates = d.getNodeCoordinates();
geometry.node_x = cell2mat(coordinates(:, 1));
geometry.node_y = cell2mat(coordinates(:, 2));
geometry.link_nodes = d.getLinkNodesIndex;
geometry.node_types = d.getNodeTypeIndex;
geometry.node_ids = string(d.getNodeNameID);
geometry.anchor_index=[];
if r38_anchor
    geometry.anchor_index=find(geometry.node_ids=="38");
    assert(isscalar(geometry.anchor_index),'R38 node missing from map');
end

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

if common_bound
    figure_units='centimeters';figure_size=[2 2 18 22];
    title_font=12.5;colorbar_font=12.5;output_dpi=350;
else
    figure_units='pixels';figure_size=[80 40 1900 1320];
    title_font=20;colorbar_font=18;output_dpi=cfg.plot.resolution;
end
fig = figure('Color','w','Units',figure_units,'Position',figure_size);
layout = tiledlayout(fig, layout_shape(1), layout_shape(2), ...
    'TileSpacing', 'compact', 'Padding', 'compact');
colormap(fig, jet(256));
for index = 1:numel(data)
    ax = nexttile(layout);
    draw_network(ax, data{index}, x_limits, y_limits, pressure_limits, ...
        'pressure',diameter_reference,dashed_limit);
    title(ax, panel_titles{index}, 'FontSize', title_font, 'FontWeight', 'normal');
end
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.FontSize = colorbar_font;
ylabel(cb, 'Pressure [m]', 'FontSize', colorbar_font);

if ~isfolder(cfg.figures_dir), mkdir(cfg.figures_dir); end
png_file = fullfile(cfg.figures_dir, ...
    ['figure10_balerma_objectives' filename_suffix '.png']);
svg_file = fullfile(cfg.figures_dir, ...
    ['figure10_balerma_objectives' filename_suffix '.svg']);
exportgraphics(fig, png_file, 'Resolution', output_dpi);
if common_bound
    exportgraphics(fig, svg_file, 'ContentType', 'vector');
else
    exportgraphics(fig, svg_file, 'ContentType', 'image', 'Resolution', 300);
end
close(fig);

generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if publish
    if ~isfolder(generated_dir), mkdir(generated_dir); end
    [~,name,ext]=fileparts(png_file);
    copyfile(png_file,fullfile(generated_dir,[name ext]),'f');
    [~,name,ext]=fileparts(svg_file);
    copyfile(svg_file,fullfile(generated_dir,[name ext]),'f');
end

% A matching six-panel water-quality map uses the same diameter encoding.
fig = figure('Color','w','Units',figure_units,'Position',figure_size);
layout = tiledlayout(fig,layout_shape(1),layout_shape(2), ...
    'TileSpacing','compact','Padding','compact');
colormap(fig,jet(256));
for index=1:numel(data)
    ax=nexttile(layout);
    draw_network(ax,data{index},x_limits,y_limits,[0 1], ...
        'chlorine',diameter_reference,dashed_limit);
    title(ax,panel_titles{index},'FontSize',title_font,'FontWeight','normal');
end
cb=colorbar(ax);
cb.Layout.Tile='east';
cb.FontSize=colorbar_font;
ylabel(cb,'Chlorine [mg/L]','FontSize',colorbar_font);
cl_png=fullfile(cfg.figures_dir, ...
    ['figure14_balerma_chlorine' filename_suffix '.png']);
cl_svg=fullfile(cfg.figures_dir, ...
    ['figure14_balerma_chlorine' filename_suffix '.svg']);
exportgraphics(fig,cl_png,'Resolution',output_dpi);
if common_bound
    exportgraphics(fig,cl_svg,'ContentType','vector');
else
    exportgraphics(fig,cl_svg,'ContentType','image','Resolution',300);
end
close(fig);
if publish
    [~,name,ext]=fileparts(cl_png);
    copyfile(cl_png,fullfile(generated_dir,[name ext]),'f');
    [~,name,ext]=fileparts(cl_svg);
    copyfile(cl_svg,fullfile(generated_dir,[name ext]),'f');
end
output_files = {png_file, svg_file, cl_png, cl_svg};
end

function draw_network(ax, item, x_limits, y_limits, color_limits, ...
    color_metric,diameter_reference,dashed_limit)
hold(ax, 'on');
for link = 1:size(item.link_nodes, 1)
    diameter = item.diameters(link);
    line_width = 0.35 + 3.65 * min(max(diameter / diameter_reference, 0), 1);
    line_style = '-';
    if diameter <= dashed_limit, line_style = '--'; end
    plot(ax, item.node_x(item.link_nodes(link, :)), ...
        item.node_y(item.link_nodes(link, :)), 'Color', [0.08 0.08 0.08], ...
        'LineWidth', line_width, 'LineStyle', line_style);
end
scatter(ax, item.node_x, item.node_y, 15, item.(color_metric), 'filled', ...
    'MarkerEdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.35);
reservoirs = find(item.node_types == 1);
reservoirs=setdiff(reservoirs,item.anchor_index);
scatter(ax, item.node_x(reservoirs), item.node_y(reservoirs), 70, ...
    [0.10 0.28 0.75], 's', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
if ~isempty(item.anchor_index)
    scatter(ax,item.node_x(item.anchor_index),item.node_y(item.anchor_index), ...
        70,[0.55 0.22 0.62],'d','filled', ...
        'MarkerEdgeColor','k','LineWidth',1.1);
end
axis(ax, 'equal');
xlim(ax, x_limits);
ylim(ax, y_limits);
clim(ax, color_limits);
axis(ax, 'off');
end
