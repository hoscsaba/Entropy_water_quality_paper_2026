function plot_objective_matrix(cfg, output_file, color_metric, edge_label_metric, panel_overrides)
%PLOT_OBJECTIVE_MATRIX Plot six selected objective designs in a 2x3 matrix.

if nargin < 3
    color_metric = 'pressure';
end
if nargin < 4
    edge_label_metric = 'diameter';
end
if nargin < 5
    panel_overrides = struct();
end
assert(ismember(string(edge_label_metric), ...
    ["diameter","flow_lps","flow_m3h_signed"]), ...
    'Unknown edge-label metric');

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));

if isfield(cfg.plot,'matrix_objectives')
    names = string(cfg.plot.matrix_objectives);
    titles = string(cfg.plot.matrix_titles);
    assert(numel(names)==6 && numel(titles)==6, ...
        'A 2-by-3 matrix requires six objective names and titles');
elseif strcmp(cfg.id,'anytown')
    names = ["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
        "chlorine_concentration","chlorine_entropy","todini"];
    titles = ["Cost","Flow-weighted entropy","Branch-hop entropy", ...
        "Chlorine concentration","Chlorine entropy","Todini index"];
else
    names = ["original", string(cfg.objectives)];
    titles = ["Original", "Cost", "Hydraulic entropy", ...
        "Chlorine concentration", "Chlorine entropy", "Todini index"];
end
diameters = cell(1, numel(names));
metric_sets = cell(1, numel(names));
if names(1)=="original"
    diameters{1} = model.original_full_diameters;
    baseline_file = fullfile(cfg.results_dir, 'baseline.mat');
    assert(isfile(baseline_file), 'Missing STACI reference state: %s', baseline_file);
    loaded_baseline = load(baseline_file, 'baseline');
    metric_sets{1} = loaded_baseline.baseline.metrics;
    first_result = 2;
else
    first_result = 1;
end
for k = first_result:numel(names)
    result_file = fullfile(cfg.results_dir, names(k) + ".mat");
    panel_key = char(names(k));
    if isfield(panel_overrides,panel_key)
        override=panel_overrides.(panel_key);
        result_file=string(override.file);
        if isfield(override,'title')
            titles(k)=string(override.title);
        end
    end
    if ~isfile(result_file)
        error('wdn:ResultMissing', ...
            'Missing %s. Run run_optimizations before make_figure3.', result_file);
    end
    loaded = load(result_file, 'result');
    if ~strcmp(loaded.result.network_id, cfg.id)
        error('wdn:ResultNetworkMismatch', 'Result %s belongs to another network.', result_file);
    end
    if ~isfield(loaded.result, 'max_constraint_violation') || ...
            loaded.result.max_constraint_violation > cfg.ga.constraint_tolerance
        error('wdn:InvalidResult', 'Result %s is missing feasibility validation.', result_file);
    end
    diameters{k} = loaded.result.full_diameters;
    metric_sets{k} = loaded.result.metrics;
end

edge_flows = cell(1,numel(names));
if string(edge_label_metric)=="flow_lps" || ...
        string(edge_label_metric)=="flow_m3h_signed"
    for k = 1:numel(names)
        assert(isfield(metric_sets{k},'link_ids') && ...
            isfield(metric_sets{k},'flows_m3s'), ...
            'Saved STACI result lacks link flows for panel %d',k);
        [found,order] = ismember(string(model.link_ids(:)), ...
            string(metric_sets{k}.link_ids(:)));
        assert(all(found),'Saved STACI result has a link-ID mismatch');
        if string(edge_label_metric)=="flow_lps"
            edge_flows{k} = 1000*abs(double(metric_sets{k}.flows_m3s(order)));
        else
            % Sign follows each INP pipe's start-to-end orientation.
            edge_flows{k} = 3600*double(metric_sets{k}.flows_m3s(order));
        end
    end
end

all_diameters = cell2mat(cellfun(@(x) x(:), diameters, 'UniformOutput', false));
design_rows = model.design_link_indices;
global_min = min(all_diameters(design_rows, :), [], 'all');
global_max = max(all_diameters(design_rows, :), [], 'all');

coords = d.getNodeCoordinates;
node_x = cell2mat(coords(:,1));
node_y = cell2mat(coords(:,2));
if isfield(cfg.plot,'display_x_node_ids')
    [found,order]=ismember(string(model.node_ids(:)), ...
        string(cfg.plot.display_x_node_ids(:)));
    assert(all(found) && numel(cfg.plot.display_x_positions)== ...
        numel(cfg.plot.display_x_node_ids), ...
        'Display-only x coordinates do not match the network nodes');
    node_x=double(cfg.plot.display_x_positions(order(:)))';
    node_x=node_x(:);
end
links = double(d.getLinkNodesIndex);
fixed_flow_arrow_length = [];
if isfield(cfg.plot,'flow_arrow_reference_link_id')
    ref_id = string(cfg.plot.flow_arrow_reference_link_id);
    ref_idx = find(string(model.link_ids(:))==ref_id,1);
    assert(~isempty(ref_idx),'Flow-arrow reference link is not in the model');
    ref_nodes = links(ref_idx,:);
    ref_dx = node_x(ref_nodes(2)) - node_x(ref_nodes(1));
    ref_dy = node_y(ref_nodes(2)) - node_y(ref_nodes(1));
    assert(abs(ref_dy)<1e-10, ...
        'Flow-arrow reference must be a horizontal displayed edge');
    fixed_flow_arrow_length = cfg.plot.flow_arrow_reference_fraction * ...
        hypot(ref_dx,ref_dy);
    assert(isfinite(fixed_flow_arrow_length) && fixed_flow_arrow_length>0, ...
        'Flow-arrow reference length must be positive');
end

node_values = cell(1, numel(names));
node_order = cell(1,numel(names));
for k = 1:numel(names)
    [found,node_order{k}] = ismember( ...
        string(model.node_ids(:)),string(metric_sets{k}.node_ids(:)));
    assert(all(found),'Saved STACI result has a node-ID mismatch');
end
switch string(color_metric)
    case "pressure"
        for k = 1:numel(names)
            node_values{k} = metric_sets{k}.pressures(node_order{k});
        end
        original_assessment_pressure = node_values{1}(model.pressure_node_indices);
        color_limits = [cfg.minimum_pressure, max(original_assessment_pressure)];
        if isfield(cfg.plot, 'pressure_limits')
            color_limits = cfg.plot.pressure_limits;
        end
        colorbar_label = cfg.plot.pressure_label;
    case "chlorine"
        for k = 1:numel(names)
            node_values{k} = metric_sets{k}.chlorine(node_order{k});
        end
        all_values = cell2mat(cellfun(@(x) x(:), node_values, 'UniformOutput', false));
        color_limits = [min(all_values, [], 'all'), max(all_values, [], 'all')];
        if isfield(cfg.plot, 'chlorine_limits')
            color_limits = cfg.plot.chlorine_limits;
        end
        colorbar_label = 'Chlorine [mg/L]';
    otherwise
        error('wdn:UnknownPlotMetric', 'Unknown node-color metric: %s', color_metric);
end
if diff(color_limits) <= eps
    color_limits = color_limits + [-1, 1];
end

if isfield(panel_overrides,'layout_shape')
    shape = panel_overrides.layout_shape;
    assert(isequal(shape,[3,2]),'The portrait option uses a 3-by-2 matrix');
    fig_position = [100, 100, 1200, 1130];
else
    shape = [2,3];
    fig_position = [100, 100, 1500, 900];
end
fig = figure('Color', 'w', 'Position', fig_position);
layout = tiledlayout(fig, shape(1), shape(2), ...
    'TileSpacing', 'compact', 'Padding', 'compact');
colormap(fig, jet);

for k = 1:numel(names)
    ax = nexttile(layout); hold(ax, 'on');
    current = diameters{k};
    for j = 1:numel(current)
        if ~ismember(j, model.design_link_indices)
            line_width = cfg.plot.fixed_link_width;
        else
            fraction = (current(j) - global_min) / max(global_max - global_min, eps);
            line_width = cfg.plot.minimum_line_width + ...
                fraction * (cfg.plot.maximum_line_width - cfg.plot.minimum_line_width);
        end
        if isfield(cfg.plot,'dash_zero_display_flow_only') && ...
                cfg.plot.dash_zero_display_flow_only
            assert(~isempty(edge_flows{k}) && ...
                string(edge_label_metric)=="flow_m3h_signed", ...
                'Zero-display-flow dashes require signed m^3/h flows');
            zero_display_limit=0.5*10^(-cfg.plot.flow_label_decimals);
            if abs(edge_flows{k}(j))<zero_display_limit
                line_style='--';
            else
                line_style='-';
            end
        else
            if isfield(cfg.plot,'dashed_diameter_threshold')
                dashed_limit=cfg.plot.dashed_diameter_threshold;
            else
                dashed_limit=cfg.minimum_diameter+cfg.plot.minimum_diameter_tolerance;
            end
            if current(j) > 0 && current(j) <= dashed_limit + 1e-9
                line_style='--';
            else
                line_style='-';
            end
        end
        plot(ax, node_x(links(j,:)), node_y(links(j,:)), 'k', ...
            'LineWidth', line_width, 'LineStyle', line_style);
    end
    if isfield(cfg.plot,'show_flow_arrows') && cfg.plot.show_flow_arrows
        assert(~isempty(edge_flows{k}), ...
            'Flow arrows require saved, signed link flows.');
        for j = 1:numel(current)
            q = edge_flows{k}(j);
            if abs(q) < cfg.plot.flow_arrow_min_m3h, continue; end
            x0 = node_x(links(j,1)); y0 = node_y(links(j,1));
            x1 = node_x(links(j,2)); y1 = node_y(links(j,2));
            if q < 0
                [x0,x1] = deal(x1,x0);
                [y0,y1] = deal(y1,y0);
            end
            vx = x1-x0; vy = y1-y0;
            length_link = hypot(vx,vy);
            if length_link < eps, continue; end
            % Keep the direction arrow off the pipe and away from the
            % signed-flow label. The head follows actual flow.
            offset = cfg.plot.flow_arrow_offset;
            if isempty(fixed_flow_arrow_length)
                % Preserve the historical proportional arrows for other
                % network figures that do not request a fixed reference.
                arrow_dx = 0.14*vx;
                arrow_dy = 0.14*vy;
                start_x = x0 + 0.72*vx - offset*vy/length_link;
                start_y = y0 + 0.72*vy + offset*vx/length_link;
            else
                % Center each arrow at 67% of the actual flow direction;
                % equal geometric lengths remain clear of short-link nodes.
                arrow_dx = fixed_flow_arrow_length*vx/length_link;
                arrow_dy = fixed_flow_arrow_length*vy/length_link;
                start_x = x0 + 0.67*vx - 0.5*arrow_dx - ...
                    offset*vy/length_link;
                start_y = y0 + 0.67*vy - 0.5*arrow_dy + ...
                    offset*vx/length_link;
            end
            quiver(ax,start_x,start_y,arrow_dx,arrow_dy,0, ...
                'Color',[0 0 0],'LineWidth',1.15, ...
                'MaxHeadSize',2.0,'AutoScale','off', ...
                'HandleVisibility','off');
        end
    end
    scatter(ax, node_x, node_y, cfg.plot.node_size, node_values{k}, ...
        'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.7);
    if isfield(cfg.plot,'source_inlet_arrow_node_ids')
        assert(~isempty(edge_flows{k}) && ...
            string(edge_label_metric)=="flow_m3h_signed", ...
            'Source arrows require saved signed link flows in m^3/h');
        source_ids=string(cfg.plot.source_inlet_arrow_node_ids);
        network_center=0.5*(min(node_x)+max(node_x));
        for source_id=source_ids(:)'
            source_idx=find(model.node_ids==source_id,1);
            assert(~isempty(source_idx), ...
                'Source-arrow node %s is absent from the model',source_id);
            % A positive signed pipe flow leaves its INP start node.
            % Summing the signed flows at this boundary gives the actual
            % source inflow for this particular saved design.
            source_flow=sum(edge_flows{k}(links(:,1)==source_idx))- ...
                sum(edge_flows{k}(links(:,2)==source_idx));
            assert(source_flow>0, ...
                'Source-arrow node %s has no positive inlet flow',source_id);
            source_x=node_x(source_idx);source_y=node_y(source_idx);
            side=sign(source_x-network_center);
            assert(side~=0,'A source arrow requires an outer node');
            arrow_start=source_x+side*0.72;
            arrow_dx=-side*0.55;
            quiver(ax,arrow_start,source_y,arrow_dx,0,0, ...
                'Color','k','LineWidth',1.5,'MaxHeadSize',1.4, ...
                'AutoScale','off','HandleVisibility','off');
            text(ax,arrow_start+0.5*arrow_dx,source_y+0.25, ...
                sprintf('%g',round(source_flow,1)), ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontSize',cfg.plot.diameter_label_font_size, ...
                'Color','k','Clipping','on');
        end
    elseif isfield(cfg.plot,'inlet_arrow_node_id')
        inlet_idx=find(model.node_ids==string(cfg.plot.inlet_arrow_node_id),1);
        assert(~isempty(inlet_idx) && isfield(cfg.plot,'inlet_arrow_m3h') && ...
            cfg.plot.inlet_arrow_m3h>0, ...
            'The inlet arrow requires an existing node and a positive flow');
        inlet_x=node_x(inlet_idx); inlet_y=node_y(inlet_idx);
        quiver(ax,inlet_x,inlet_y+0.70,0,-0.53,0, ...
            'Color','k','LineWidth',1.5,'MaxHeadSize',1.4, ...
            'AutoScale','off','HandleVisibility','off');
        text(ax,inlet_x,inlet_y+0.88, ...
            sprintf('%g',cfg.plot.inlet_arrow_m3h), ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontSize',cfg.plot.diameter_label_font_size, ...
            'Color','k','Clipping','on');
    end
    if isfield(cfg.plot, 'source_reservoir_node_ids')
        wdn.mark_hydraulic_equipment(ax, node_x, node_y, links, model, cfg, 1);
    end
    if isfield(cfg.plot, 'diameter_label_link_ids')
        label_link_ids = string(cfg.plot.diameter_label_link_ids);
    else
        label_link_ids = model.link_ids;
    end
    for j = find(ismember(model.link_ids, label_link_ids))
        link_id = char(model.link_ids(j));
        label_fraction = 0.5;
        if isfield(cfg.plot.diameter_label_fraction_by_link, link_id)
            label_fraction = cfg.plot.diameter_label_fraction_by_link.(link_id);
        end
        label_offset = [0, 0];
        if isfield(cfg.plot.diameter_label_offset_by_link, link_id)
            label_offset = cfg.plot.diameter_label_offset_by_link.(link_id);
        end
        label_x = (1 - label_fraction) * node_x(links(j,1)) + ...
            label_fraction * node_x(links(j,2)) + label_offset(1);
        label_y = (1 - label_fraction) * node_y(links(j,1)) + ...
            label_fraction * node_y(links(j,2)) + label_offset(2);
        label_rotation = 0;
        if isfield(cfg.plot,'rotate_diagonal_edge_labels') && ...
                cfg.plot.rotate_diagonal_edge_labels
            dx = node_x(links(j,2)) - node_x(links(j,1));
            dy = node_y(links(j,2)) - node_y(links(j,1));
            if abs(dx) > 1e-10 && abs(dy) > 1e-10
                label_rotation = atan2d(dy,dx);
                if label_rotation > 90
                    label_rotation = label_rotation - 180;
                elseif label_rotation < -90
                    label_rotation = label_rotation + 180;
                end
            end
        end
        if string(edge_label_metric)=="flow_lps"
            q = edge_flows{k}(j);
            if q < 0.005
                label_text = '0';
            elseif q < 1
                label_text = sprintf('%.2f',q);
            elseif q < 100
                label_text = sprintf('%.1f',q);
            else
                label_text = sprintf('%.0f',q);
            end
        elseif string(edge_label_metric)=="flow_m3h_signed"
            q = edge_flows{k}(j);
            decimals = 2;
            if isfield(cfg.plot,'flow_label_decimals')
                decimals = cfg.plot.flow_label_decimals;
            end
            if abs(q) < 0.5*10^(-decimals)
                label_text = sprintf('%.*f',decimals,0);
            else
                label_text = sprintf('%.*f',decimals,q);
            end
        else
            label_text = sprintf('%g', round(current(j),1));
        end
        label_font_size = cfg.plot.diameter_label_font_size;
        if string(edge_label_metric)=="diameter" && names(k)=="original" && ...
                isfield(cfg.plot, 'link_id_labels_on_original') && ...
                cfg.plot.link_id_labels_on_original
            label_text = sprintf('L%s', link_id);
            if isfield(cfg.plot, 'link_id_label_font_size')
                label_font_size = cfg.plot.link_id_label_font_size;
            end
        end
        text(ax, label_x, label_y, label_text, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', label_font_size, 'Rotation', label_rotation, ...
            'BackgroundColor', 'w', 'Margin', 0.5, 'Clipping', 'on');
    end
    clim(ax, color_limits);
    axis(ax, 'equal');
    if isfield(cfg.plot, 'axis_padding_fraction')
        x_padding = (max(node_x) - min(node_x)) * cfg.plot.axis_padding_fraction;
        y_padding = (max(node_y) - min(node_y)) * cfg.plot.axis_padding_fraction;
    else
        x_padding = cfg.plot.axis_padding;
        y_padding = cfg.plot.axis_padding;
    end
    if isfield(cfg.plot,'x_padding'),x_padding=cfg.plot.x_padding;end
    if isfield(cfg.plot,'y_padding'),y_padding=cfg.plot.y_padding;end
    xlim(ax, [min(node_x) - x_padding, max(node_x) + x_padding]);
    ylim(ax, [min(node_y) - y_padding, max(node_y) + y_padding]);
    axis(ax, 'off');
    if isfield(cfg.plot,'force_canvas_bounds') && ...
            cfg.plot.force_canvas_bounds
        scatter(ax,[min(node_x)-x_padding,max(node_x)+x_padding], ...
            [min(node_y)-y_padding,max(node_y)+y_padding],1,'w','filled', ...
            'MarkerEdgeColor','none','HandleVisibility','off');
    end
    title_font_size=12;
    if isfield(cfg.plot,'panel_title_font_size')
        title_font_size=cfg.plot.panel_title_font_size;
    end
    title(ax, sprintf('(%c) %s', char('a' + k - 1), titles(k)), ...
        'FontWeight', 'normal', 'FontSize', title_font_size);
end

cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = colorbar_label;
colorbar_font_size=11;
if isfield(cfg.plot,'colorbar_font_size')
    colorbar_font_size=cfg.plot.colorbar_font_size;
end
cb.FontSize = colorbar_font_size;
cb.Label.FontSize = colorbar_font_size;
[folder,basename]=fileparts(output_file);
if isfield(cfg.plot,'print_full_canvas') && cfg.plot.print_full_canvas
    set(fig,'PaperPositionMode','auto');
    print(fig,output_file,'-dpng',sprintf('-r%d',cfg.plot.resolution));
    print(fig,fullfile(folder,[basename '.svg']),'-dsvg');
else
    exportgraphics(fig, output_file, 'Resolution', cfg.plot.resolution);
    exportgraphics(fig,fullfile(folder,[basename '.svg']), ...
        'ContentType','vector');
end
close(fig);
end
