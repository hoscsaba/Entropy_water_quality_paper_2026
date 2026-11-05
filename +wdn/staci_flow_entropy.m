function [value, details] = staci_flow_entropy(staci, cfg, node_multiplier)
%STACI_FLOW_ENTROPY Paper flow entropy on the physical service graph.
% Virtual EPANET boundary links, source adapters and pressure-anchor stubs
% are excluded from service branching. Their supply is transferred to the
% physical endpoint only when flow enters the service graph.

nodes = staci.nodeResults();
links = staci.linkResults();
node_ids = string(nodes.id(:));
link_ids = string(links.id(:));
from = string(links.from_node(:));
to = string(links.to_node(:));
flow = double(links.flow_rate_m3s(:));
demands = double(nodes.demand_m3s(:));
n = numel(node_ids);
if isempty(node_multiplier)
    node_multiplier = ones(n, 1);
else
    node_multiplier = double(node_multiplier(:));
    assert(numel(node_multiplier) == n, 'STACI entropy multiplier size mismatch');
end
[found_from, from_index] = ismember(from, node_ids);
[found_to, to_index] = ismember(to, node_ids);
assert(all(found_from), 'STACI link refers to an unknown start node');
physical = ismember(link_ids, string(cfg.design_link_ids));
physical_nodes = unique([from_index(physical); to_index(physical)]);
physical_mask = false(n, 1);
physical_mask(physical_nodes) = true;
reverse = flow < 0;
oriented_from = from_index;
oriented_to = to_index;
oriented_from(reverse & found_to) = to_index(reverse & found_to);
oriented_to(reverse & found_to) = from_index(reverse & found_to);
magnitude = abs(flow);

supply = zeros(n, 1);
supply(physical_nodes) = max(-demands(physical_nodes), 0);
% The STACI INP importer represents a reservoir with a one-node boundary
% link. Negative boundary flow supplies the physical reservoir node.
one_node_boundary = ~found_to & physical_mask(from_index);
for k = find(one_node_boundary(:))'
    supply(from_index(k)) = supply(from_index(k)) + max(-flow(k), 0);
end
% For adapters such as Anytown pump 82 and Tanyimboh P_input_2, move only
% entering flow into the physical graph. Zero-flow pressure stubs add zero.
destination_physical = false(size(found_to));
destination_physical(found_to) = physical_mask(oriented_to(found_to));
adapter = ~physical & found_to & destination_physical & ...
    ~physical_mask(oriented_from);
for k = find(adapter(:))'
    supply(oriented_to(k)) = supply(oriented_to(k)) + magnitude(k);
end
total_supply = sum(supply);
assert(total_supply > 0, 'STACI entropy has no physical external supply');
shares = supply(supply > 0) / total_supply;
value = -sum(shares .* log(shares) .* node_multiplier(supply > 0));
% Equivalent to the nodal sum of p*log(p), but linear in the number of
% links. The former per-node find() rescanned every link on every iteration
% and dominated the 454-pipe Balerma genetic search.
physical_from = oriented_from(physical);
physical_flow = magnitude(physical);
withdraw = zeros(n, 1);
withdraw(physical_nodes) = max(demands(physical_nodes), 0);
throughflow = accumarray(physical_from, physical_flow, [n, 1]) + withdraw;
active_link = physical_flow > 0 & throughflow(physical_from) > eps;
if any(active_link)
    source = physical_from(active_link);
    q = physical_flow(active_link);
    value = value - sum(q .* log(q ./ throughflow(source)) .* ...
        node_multiplier(source)) / total_supply;
end
active_demand = withdraw > 0 & throughflow > eps;
if any(active_demand)
    q = withdraw(active_demand);
    value = value - sum(q .* log(q ./ throughflow(active_demand)) .* ...
        node_multiplier(active_demand)) / total_supply;
end
if nargout > 1
    node_entropy = zeros(n, 1);
    if any(active_link)
        source = physical_from(active_link);
        q = physical_flow(active_link);
        node_entropy = node_entropy + accumarray(source, ...
            -q .* log(q ./ throughflow(source)) .* ...
            node_multiplier(source) / total_supply, [n, 1]);
    end
    if any(active_demand)
        demand_nodes = find(active_demand);
        q = withdraw(active_demand);
        node_entropy(demand_nodes) = node_entropy(demand_nodes) - ...
            q .* log(q ./ throughflow(active_demand)) .* ...
            node_multiplier(active_demand) / total_supply;
    end
    details.total_supply = total_supply;
    details.external_supply = supply;
    details.throughflow = throughflow;
    details.source_entropy = -sum(shares .* log(shares) .* ...
        node_multiplier(supply > 0));
    details.node_entropy = node_entropy;
end
end
