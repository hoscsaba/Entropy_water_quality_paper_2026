function make_anytown_schematic
%MAKE_ANYTOWN_SCHEMATIC Plot original topology and topology-only node weights.
% This figure reads the EPANET input but never calls a hydraulic solver.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config_anchor_replay(network_dir);
wdn.setup_toolkit(cfg);
if ~isfolder(cfg.figures_dir),mkdir(cfg.figures_dir);end

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
coords = d.getNodeCoordinates;
node_x = cell2mat(coords(:,1));
node_y = cell2mat(coords(:,2));
links = double(d.getLinkNodesIndex);
base_categories = d.getNodeBaseDemands;
base_demands = zeros(numel(model.node_ids),1);
for category = 1:numel(base_categories)
    base_demands = base_demands + double(base_categories{category}(:));
end
pump_links = ismember(model.link_ids,string(cfg.plot.pump_link_ids));
assert(nnz(pump_links)==1,'Expected the one Anytown supply pump');
node_types = double(d.getNodeTypeIndex);
reservoir_ids = model.node_ids(node_types(:)==2);
anchor_ids = string(cfg.pressure_anchor_node_ids(:));
anchor_entries = strings(numel(anchor_ids),1);
for j = 1:numel(anchor_ids)
    [found,anchor_index] = ismember(anchor_ids(j),model.node_ids);
    assert(found,'Pressure-anchor node missing');
    adapter = find(any(links==anchor_index,2) & ...
        ismember(model.link_ids(:),string(cfg.entropy_excluded_link_ids)) & ...
        ~pump_links(:));
    assert(isscalar(adapter),'Each reservoir needs one fixed connection');
    other = links(adapter,links(adapter,:)~=anchor_index);
    anchor_entries(j) = model.node_ids(other);
end
source_ids = unique([reservoir_ids(:);string(cfg.source_node_ids(:)); ...
    model.node_ids(links(pump_links,2)); ...
    model.node_ids(base_demands<0);anchor_ids;anchor_entries],'stable');
weighting = wdn.topology_branch_hop_weights(model.node_ids,links, ...
    model.design_link_indices,base_demands,source_ids);
weights_table = table(model.node_ids(:),weighting.branch_hops, ...
    weighting.weights,weighting.physical_degree, ...
    weighting.demand_exit,weighting.is_branch, ...
    'VariableNames',{'NodeID','BranchHops','Weight', ...
    'PhysicalDegree','DemandExit','IsBranch'});
writetable(weights_table,fullfile(cfg.results_dir, ...
    'topology_branch_hop_weights.csv'));

fig = figure('Color', 'w', 'Position', [100 100 1500 810]);
ax = axes(fig,'Position',[0.04 0.09 0.77 0.85]); hold(ax, 'on');
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
outer_ids = ["20","30","40","50","55","75","110","115", ...
    "120","130","140","170"];
interior_ids = ["60","70","80","90","100","150","160"];
physical_ids = model.node_ids(model.physical_node_indices);
assert(isequal(sort([outer_ids(:);interior_ids(:)]),sort(physical_ids(:))), ...
    'Outer and interior labels must cover every physical junction');
for n = 1:numel(model.node_ids)
    if ismember(string(model.node_ids(n)), ["10","65","165"])
        continue; % Equipment labels identify these nodes without overlap.
    end
    id = string(model.node_ids(n));
    if ismember(id,outer_ids)
        offset = outer_label_offset(id);
        label = sprintf('%s: 1/%d',id,1+weighting.branch_hops(n));
        label_size = 11.2;
    else
        offset = [0,135];
        label = char(id);
        label_size = 12;
    end
    text(ax, node_x(n)+offset(1), node_y(n)+offset(2), label, ...
        'FontSize', label_size, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'BackgroundColor', 'w', 'Margin', 0.5);
end

% The physical N-1 scenario restores reservoirs at the two nominal
% pressure-anchor sites; show those reservoirs on this source-weight map.
cfg.plot.source_reservoir_node_ids = {'10','65','165'};
cfg.plot.pressure_anchor_node_ids = {};
cfg.plot.equipment_label_offsets.R65 = [110, -20];
cfg.plot.equipment_label_offsets.R165 = [-350, 130];
cfg.plot.equipment_label_offsets.R10 = [100, -170];
cfg.plot.equipment_label_offsets.P82 = [100, 100];
wdn.mark_hydraulic_equipment(ax, node_x, node_y, links, model, cfg, 1.25);

% Each link ID and original diameter is parallel to its pipe. Normalize the
% rotation to [-90,90] degrees so every label can be read upright.
physical = model.design_link_indices;
for a = 1:numel(physical)
    j = physical(a);
    x = node_x(links(j,:)); y = node_y(links(j,:));
    tangent = [x(2)-x(1), y(2)-y(1)];
    normal = [-tangent(2), tangent(1)] / norm(tangent);
    side = (-1)^a;
    position = [mean(x),mean(y)] + 90*side*normal;
    rotation = atan2d(tangent(2),tangent(1));
    if rotation > 90
        rotation = rotation - 180;
    elseif rotation < -90
        rotation = rotation + 180;
    end
    % Resolve four dense label clusters in the original Anytown layout.
    switch char(model.link_ids(j))
        case '72', position = position + [170, 0];
        case '12', position = position + [120, 110];
        case '24', position = position + [-90, 80];
        case '34', position = position + [-40, 85];
    end
    diameter = model.original_full_diameters(j);
    label = sprintf('L%s: %g in', char(model.link_ids(j)), diameter);
    text(ax,position(1),position(2),label,'FontSize',8.5, ...
        'Rotation',rotation, ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'BackgroundColor','w','Margin',0.3,'Clipping','on');
end

axis(ax, 'equal');
x_padding = 0.08 * (max(node_x) - min(node_x));
y_padding = 0.10 * (max(node_y) - min(node_y));
xlim(ax, [min(node_x)-x_padding, max(node_x)+x_padding]);
ylim(ax, [min(node_y)-y_padding, max(node_y)+y_padding]);
axis(ax, 'off');

% Put the dense interior-node weights in an unboxed vertical list at upper
% right, leaving their node IDs in the network itself.
list_ax = axes(fig,'Position',[0.835 0.46 0.155 0.45]);
hold(list_ax,'on'); axis(list_ax,[0 1 0 1]); axis(list_ax,'off');
text(list_ax,0,0.95,'internal node weights:', ...
    'FontSize',12,'FontWeight','bold','VerticalAlignment','top');
for k = 1:numel(interior_ids)
    [found,index] = ismember(interior_ids(k),model.node_ids);
    assert(found);
    text(list_ax,0.04,0.84-0.105*(k-1), ...
        sprintf('%s: 1/%d',interior_ids(k),1+weighting.branch_hops(index)), ...
        'FontSize',11.5,'VerticalAlignment','middle');
end

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

function offset = outer_label_offset(id)
% Offsets are in the schematic's coordinate units, outside the main grid.
switch char(id)
    case '20', offset = [50,-230];
    case '30', offset = [150,65];
    case '40', offset = [0,100];
    case '50', offset = [0,170];
    case '55', offset = [0,155];
    case '75', offset = [-170,130];
    case '110', offset = [0,-220];
    case '115', offset = [-130,130];
    case '120', offset = [0,190];
    case '130', offset = [-135,-195];
    case '140', offset = [-290,60];
    case '170', offset = [250,90];
    otherwise, error('Unknown outer node %s',id);
end
end
