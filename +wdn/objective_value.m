function value = objective_value(x, d, cfg, model, objective_name)
%OBJECTIVE_VALUE Convert physical objectives to MATLAB-GA minimisation values.

wdn.apply_design(d, x, cfg, model);
d.solveCompleteHydraulics;

switch string(objective_name)
    case "cost"
        value = wdn.pipe_cost(x, model.link_lengths(model.design_link_indices), cfg);
    case "hydraulic_entropy"
        value = -wdn.flow_entropy(d, model, []);
    case "chlorine_concentration"
        chlorine = wdn.chlorine_state(d, cfg);
        value = -sum(chlorine(model.quality_node_indices).^2);
    case "chlorine_entropy"
        chlorine = wdn.chlorine_state(d, cfg);
        value = -wdn.flow_entropy(d, model, chlorine);
    case "todini"
        value = -wdn.todini_index(d, cfg);
    otherwise
        error('wdn:UnknownObjective', 'Unknown objective: %s', objective_name);
end

if ~isfinite(value)
    value = realmax('double') / 100;
end
end
