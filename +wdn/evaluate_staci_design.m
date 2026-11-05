function [metrics, violation] = evaluate_staci_design(staci, cfg, x, link_order, original_diameters)
%EVALUATE_STACI_DESIGN All five paper metrics from one resident STACI model.
% x is in the network's published diameter unit (inches or millimetres).
if strcmp(cfg.id, 'anytown')
    diameter_scale = 0.0254;
    length_scale = 1 / 0.3048;
    head_scale = 0.3048;
    flow_scale = 6.30901964e-5;
else
    diameter_scale = 0.001;
    length_scale = 1;
    head_scale = 1;
    if strcmp(cfg.id, 'tanyimboh_templeman')
        flow_scale = 1 / 3600;
    else
        flow_scale = 0.001;
    end
end
design_ids = string(cfg.design_link_ids(:));
x = double(x(:));
assert(numel(x) == numel(design_ids), 'Design length mismatch');
staci.setLinkProperty(design_ids, 'diameter_m', x * diameter_scale);
status = staci.solveHydraulics();
assert(status.converged, 'STACI hydraulics did not converge');
nodes = staci.nodeResults();
links = staci.linkResults();
quality = staci.solveSteadyQuality('chemical');
node_ids = string(nodes.id(:));
link_ids = string(links.id(:));
quality_ids = string(quality.node_ids(:));
[found_quality, qi] = ismember(node_ids, quality_ids);
[found_pressure, pidx] = ismember(string(cfg.pressure_node_ids(:)), node_ids);
[found_assessment, ai] = ismember(string(cfg.quality_node_ids(:)), node_ids);
[found_links, li] = ismember(string(link_order(:)), link_ids);
assert(all([found_quality; found_pressure; found_assessment; found_links]), ...
    'Configured STACI node or link ID is missing');
chlorine = 1000 * double(quality.node_concentration_kgm3(qi));
pressure = double(nodes.pressure_head_m(:));
if strcmp(cfg.id, 'anytown')
    pressure = pressure / (0.3048 * cfg.pressure_to_head);
end
lengths = staci.getLinkProperty(design_ids, 'length_m');
metrics.cost = wdn.pipe_cost(x, double(lengths(:)) * length_scale, cfg);
metrics.hydraulic_entropy = wdn.staci_flow_entropy(staci, cfg, []);
metrics.chlorine_concentration = sum(chlorine(ai).^2);
metrics.chlorine_entropy = wdn.staci_flow_entropy(staci, cfg, chlorine);
metrics.todini = wdn.staci_todini_index(staci, cfg);
metrics.node_ids = cellstr(node_ids);
metrics.link_ids = cellstr(link_ids);
metrics.pressures = pressure;
metrics.heads_m = double(nodes.total_head_m(:));
metrics.heads = metrics.heads_m / head_scale;
metrics.flows_m3s = double(links.flow_rate_m3s(:));
metrics.flows = metrics.flows_m3s(li) / flow_scale;
metrics.chlorine = chlorine;
metrics.minimum_consumer_chlorine_mgL = ...
    min(chlorine(double(nodes.demand_m3s(:)) > pi/4*0.010^2*0.01));
full_diameters = double(original_diameters(:)');
[found_design, di] = ismember(design_ids, string(link_order(:)));
assert(all(found_design), 'Design link missing from output link order');
full_diameters(di) = x;
metrics.full_diameters = full_diameters;
constraints = cfg.minimum_pressure - pressure(pidx);
if isfinite(cfg.maximum_pressure)
    constraints = [constraints; pressure(pidx) - cfg.maximum_pressure];
end
if isfield(cfg, 'pressure_anchor_node_ids') && ...
        ~isempty(cfg.pressure_anchor_node_ids)
    [found_anchor, anchor_index] = ismember( ...
        string(cfg.pressure_anchor_node_ids(:)), node_ids);
    assert(all(found_anchor), 'Pressure anchor node missing');
    anchor_ft = double(nodes.total_head_m(anchor_index)) / 0.3048;
    constraints = [constraints; abs(anchor_ft(:) - ...
        cfg.pressure_anchor_target_heads(:)) - ...
        cfg.pressure_anchor_head_tolerance];
end
violation = max([0; constraints(:)]);
end
