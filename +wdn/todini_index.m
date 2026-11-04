function value = todini_index(d, cfg)
%TODINI_INDEX Calculate the positive Todini resilience index.

head_raw = d.getNodeHydraulicHead;
head = double(head_raw(:));
demands = d.getNodeActualDemand;
if iscell(demands), demands = cell2mat(demands); end
demands = double(demands(:));
elevation_raw = d.getNodeElevations;
junctions_raw = d.getNodeJunctionIndex;
elevation = double(elevation_raw(:));
junctions = double(junctions_raw(:));
% EPANET adapters can represent a prescribed inflow as a negative junction
% demand (as node 2 does in the Tanyimboh--Templeman model), so source nodes
% must be identified from actual negative demand rather than node type alone.
sources = find(demands < 0);
if isfield(cfg, 'pressure_to_head')
    pressure_to_head = cfg.pressure_to_head;
else
    pressure_to_head = 1;
end
required_head = elevation + cfg.minimum_pressure * pressure_to_head;

positive_demands = max(demands(junctions), 0);
numerator = sum(positive_demands .* (head(junctions) - required_head(junctions)));
supply_energy = sum(max(-demands(sources), 0) .* head(sources));

pump_energy = 0;
pumps_raw = d.getLinkPumpIndex;
flows_raw = d.getLinkFlows;
headloss_raw = d.getLinkHeadloss;
pumps = double(pumps_raw(:));
flows = double(flows_raw(:));
headloss = double(headloss_raw(:));
for k = pumps(:)'
    if flows(k) > 0 && -headloss(k) > 0
        pump_energy = pump_energy + flows(k) * (-headloss(k));
    end
end

required_energy = sum(positive_demands .* required_head(junctions));
denominator = supply_energy + pump_energy - required_energy;
if denominator <= 0
    value = 0;
else
    value = numerator / denominator;
end
end
