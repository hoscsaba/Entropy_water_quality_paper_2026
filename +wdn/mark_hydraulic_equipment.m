function mark_hydraulic_equipment(ax, node_x, node_y, links, model, cfg, scale)
%MARK_HYDRAULIC_EQUIPMENT Overlay source, pressure-anchor, and pump symbols.

if nargin < 7
    scale = 1;
end

node_ids = string(model.node_ids);
link_ids = string(model.link_ids);

[found_source, source_idx] = ismember(string(cfg.plot.source_reservoir_node_ids), node_ids);
[found_anchor, anchor_idx] = ismember(string(cfg.plot.pressure_anchor_node_ids), node_ids);
[found_pump, pump_idx] = ismember(string(cfg.plot.pump_link_ids), link_ids);
if ~all(found_source) || ~all(found_anchor) || ~all(found_pump)
    error('wdn:EquipmentMarkerID', 'Configured equipment marker ID is missing.');
end

marker_size = cfg.plot.equipment_marker_size * scale;
font_size = cfg.plot.equipment_label_font_size * scale;
offset = cfg.plot.equipment_label_offset * scale;

scatter(ax, node_x(source_idx), node_y(source_idx), marker_size, ...
    [0.15 0.45 0.95], 's', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
for k = 1:numel(source_idx)
    label_offset = equipment_offset(cfg, 'R', cfg.plot.source_reservoir_node_ids{k}, offset, scale);
    text(ax, node_x(source_idx(k)) + label_offset(1), node_y(source_idx(k)) + label_offset(2), ...
        char("R" + string(cfg.plot.source_reservoir_node_ids{k})), ...
        'FontSize', font_size, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'Margin', 0.5);
end

scatter(ax, node_x(anchor_idx), node_y(anchor_idx), marker_size, ...
    [0.10 0.78 0.78], 'd', 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.1);
for k = 1:numel(anchor_idx)
    label_offset = equipment_offset(cfg, 'PA', cfg.plot.pressure_anchor_node_ids{k}, offset, scale);
    text(ax, node_x(anchor_idx(k)) + label_offset(1), node_y(anchor_idx(k)) + label_offset(2), ...
        char("PA" + string(cfg.plot.pressure_anchor_node_ids{k})), ...
        'FontSize', font_size, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'Margin', 0.5);
end

for k = 1:numel(pump_idx)
    pump_nodes = links(pump_idx(k), :);
    start_point = [node_x(pump_nodes(1)), node_y(pump_nodes(1))];
    end_point = [node_x(pump_nodes(2)), node_y(pump_nodes(2))];
    direction = end_point - start_point;
    direction = direction / norm(direction);
    normal = [-direction(2), direction(1)];
    midpoint = 0.5 * (start_point + end_point);
    if isfield(cfg.plot, 'pump_symbol_radius')
        radius = cfg.plot.pump_symbol_radius * scale;
    else
        radius = 0.75 * sqrt(marker_size) * scale;
    end

    % Standard pump symbol: a circle enclosing a filled triangle. The
    % triangle points from the EPANET start node toward the end node, which
    % is the admissible delivery direction of the pump link.
    circle_angle = linspace(0, 2*pi, 80);
    patch(ax, midpoint(1) + radius*cos(circle_angle), ...
        midpoint(2) + radius*sin(circle_angle), 'w', ...
        'EdgeColor', 'k', 'LineWidth', 1.2);
    tip = midpoint + 0.72 * radius * direction;
    base_center = midpoint - 0.42 * radius * direction;
    vertex_2 = base_center + 0.48 * radius * normal;
    vertex_3 = base_center - 0.48 * radius * normal;
    patch(ax, [tip(1), vertex_2(1), vertex_3(1)], ...
        [tip(2), vertex_2(2), vertex_3(2)], [0.90 0.25 0.70], ...
        'EdgeColor', 'k', 'LineWidth', 0.8);
    label_offset = equipment_offset(cfg, 'P', cfg.plot.pump_link_ids{k}, offset, scale);
    text(ax, midpoint(1) + label_offset(1), midpoint(2) + label_offset(2), ...
        char("P" + string(cfg.plot.pump_link_ids{k})), ...
        'FontSize', font_size, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'Margin', 0.5);
end
end

function value = equipment_offset(cfg, prefix, id, fallback, scale)
value = fallback;
if isfield(cfg.plot,'equipment_label_offsets')
    key = char(string(prefix) + string(id));
    if isfield(cfg.plot.equipment_label_offsets,key)
        value = cfg.plot.equipment_label_offsets.(key)*scale;
    end
end
end
