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
assert(ismember(string(edge_label_metric),["diameter","flow_lps"]), ...
    'Unknown edge-label metric');

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));

if strcmp(cfg.id,'anytown')
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

flow_lps = cell(1,numel(names));
if string(edge_label_metric)=="flow_lps"
    for k = 1:numel(names)
        assert(isfield(metric_sets{k},'link_ids') && ...
            isfield(metric_sets{k},'flows_m3s'), ...
            'Saved STACI result lacks link flows for panel %d',k);
        [found,order] = ismember(string(model.link_ids(:)), ...
            string(metric_sets{k}.link_ids(:)));
        assert(all(found),'Saved STACI result has a link-ID mismatch');
        flow_lps{k} = 1000*abs(double(metric_sets{k}.flows_m3s(order)));
    end
end

all_diameters = cell2mat(cellfun(@(x) x(:), diameters, 'UniformOutput', false));
design_rows = model.design_link_indices;
global_min = min(all_diameters(design_rows, :), [], 'all');
global_max = max(all_diameters(design_rows, :), [], 'all');

coords = d.getNodeCoordinates;
node_x = cell2mat(coords(:,1));
node_y = cell2mat(coords(:,2));
links = double(d.getLinkNodesIndex);

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

fig = figure('Color', 'w', 'Position', [100, 100, 1500, 900]);
layout = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
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
        if ismember(j, model.design_link_indices) && ...
                current(j) <= cfg.minimum_diameter + cfg.plot.minimum_diameter_tolerance
            line_style = '--';
        else
            line_style = '-';
        end
        plot(ax, node_x(links(j,:)), node_y(links(j,:)), 'k', ...
            'LineWidth', line_width, 'LineStyle', line_style);
    end
    scatter(ax, node_x, node_y, cfg.plot.node_size, node_values{k}, ...
        'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.7);
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
        if string(edge_label_metric)=="flow_lps"
            q = flow_lps{k}(j);
            if q < 0.005
                label_text = '0';
            elseif q < 1
                label_text = sprintf('%.2f',q);
            elseif q < 100
                label_text = sprintf('%.1f',q);
            else
                label_text = sprintf('%.0f',q);
            end
        else
            label_text = sprintf('%.1f', current(j));
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
            'FontSize', label_font_size, ...
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
    xlim(ax, [min(node_x) - x_padding, max(node_x) + x_padding]);
    ylim(ax, [min(node_y) - y_padding, max(node_y) + y_padding]);
    axis(ax, 'off');
    title(ax, sprintf('(%c) %s', char('a' + k - 1), titles(k)), ...
        'FontWeight', 'normal', 'FontSize', 17);
end

cb = colorbar;
cb.Layout.Tile = 'east';
cb.Label.String = colorbar_label;
cb.FontSize = 15;
cb.Label.FontSize = 17;
exportgraphics(fig, output_file, 'Resolution', cfg.plot.resolution);
[folder,basename]=fileparts(output_file);
exportgraphics(fig,fullfile(folder,[basename '.svg']), ...
    'ContentType','vector');
close(fig);
end
