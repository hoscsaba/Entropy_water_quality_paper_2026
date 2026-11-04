function [c, ceq] = pressure_constraints(x, d, cfg, model)
%PRESSURE_CONSTRAINTS Enforce consumer pressure and pressure-anchor heads.

wdn.apply_design(d, x, cfg, model);
d.solveCompleteHydraulics;
pressure_raw = d.getNodePressure;
pressure = double(pressure_raw(:));
c = cfg.minimum_pressure - pressure(model.pressure_node_indices);
if isfinite(cfg.maximum_pressure)
    c = [c; pressure(model.pressure_node_indices) - cfg.maximum_pressure];
end
if isfield(model, 'pressure_anchor_node_indices') && ...
        ~isempty(model.pressure_anchor_node_indices)
    head_raw = d.getNodeHydraulicHead;
    head = double(head_raw(:));
    anchor_head = head(model.pressure_anchor_node_indices);
    target_head = double(cfg.pressure_anchor_target_heads(:));
    tolerance = double(cfg.pressure_anchor_head_tolerance);
    c = [c; abs(anchor_head - target_head) - tolerance];
end
c = c(:);
ceq = [];
end
