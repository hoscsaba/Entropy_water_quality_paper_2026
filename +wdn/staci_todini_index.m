function value = staci_todini_index(staci, cfg)
%STACI_TODINI_INDEX Todini index using SI heads, flows and demands.
% Reservoirs in STACI are one-node constant-head boundary links. Their
% negative flow is the supplied volume rate; negative-demand junctions are
% additional sources. Pump gain is counted once as flow times head gain.
nodes = staci.nodeResults();
links = staci.linkResults();
id = string(nodes.id(:));
head = double(nodes.total_head_m(:));
demand = double(nodes.demand_m3s(:));
elevation = double(nodes.elevation_m(:));
if strcmp(cfg.id, 'anytown')
    minimum_head = cfg.minimum_pressure * cfg.pressure_to_head * 0.3048;
else
    minimum_head = cfg.minimum_pressure;
end
required = elevation + minimum_head;
consumer = ismember(id, string(cfg.pressure_node_ids(:)));
positive = max(demand(consumer), 0);
numerator = sum(positive .* (head(consumer) - required(consumer)));
required_energy = sum(positive .* required(consumer));
supply_energy = sum(max(-demand, 0) .* head);
link_type = string(links.type(:));
link_from = string(links.from_node(:));
link_to = string(links.to_node(:));
flow = double(links.flow_rate_m3s(:));
boundary = link_type == "KonstNyomas" & link_to == "";
for k = find(boundary(:))'
    [found, idx] = ismember(link_from(k), id);
    assert(found, 'Boundary link has no source node');
    supply_energy = supply_energy + max(-flow(k), 0) * head(idx);
end
pump = link_type == "Szivattyu";
pump_energy = sum(max(flow(pump), 0) .* max(-double(links.headloss_m(pump)), 0));
denominator = supply_energy + pump_energy - required_energy;
if denominator <= 0
    value = 0;
else
    value = numerator / denominator;
end
end
