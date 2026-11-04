function metrics = evaluate_design(d, x, cfg, model, include_quality)
%EVALUATE_DESIGN Return positive physical metrics for one candidate design.

if nargin < 5
    include_quality = true;
end

wdn.apply_design(d, x, cfg, model);
d.solveCompleteHydraulics;

pressures_raw = d.getNodePressure;
heads_raw = d.getNodeHydraulicHead;
flows_raw = d.getLinkFlows;
pressures = double(pressures_raw(:));
heads = double(heads_raw(:));
flows = double(flows_raw(:));
metrics.cost = wdn.pipe_cost(x, model.link_lengths(model.design_link_indices), cfg);
metrics.hydraulic_entropy = wdn.flow_entropy(d, model, []);
metrics.todini = wdn.todini_index(d, cfg);

if include_quality
    chlorine = wdn.chlorine_state(d, cfg);
    metrics.chlorine_concentration = ...
        sum(chlorine(model.quality_node_indices).^2);
    metrics.chlorine_entropy = wdn.flow_entropy(d, model, chlorine);
else
    chlorine = [];
    metrics.chlorine_concentration = NaN;
    metrics.chlorine_entropy = NaN;
end
metrics.pressures = pressures;
metrics.heads = heads;
metrics.flows = flows;
metrics.chlorine = chlorine;
full_diameters = d.getLinkDiameter;
metrics.full_diameters = double(full_diameters(:)');
end
