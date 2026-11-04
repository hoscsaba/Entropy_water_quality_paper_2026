function [entropy_value, details] = flow_entropy(d, model, node_multiplier)
%FLOW_ENTROPY Tanyimboh--Templeman flow entropy (natural-log units).
% Fixed EPANET supply adapters are removed from the physical graph and their
% inflow is transferred to the physical node at the downstream end.

flows_raw = d.getLinkFlows;
flows = double(flows_raw(:));
demands_raw = d.getNodeActualDemand;
if iscell(demands_raw), demands_raw = cell2mat(demands_raw); end
demands = double(demands_raw(:));
if isfield(model, 'link_nodes')
    links = model.link_nodes;
    num_nodes = model.num_nodes;
    physical_links = model.physical_link_indices;
    physical_nodes = model.physical_node_indices;
    physical_node_mask = model.physical_node_mask;
else
    links = double(d.getLinkNodesIndex);
    num_nodes = double(d.getNodeCount);
    included = true(size(flows));
    included(model.entropy_excluded_link_indices) = false;
    physical_links = find(included);
    physical_nodes = unique(links(physical_links, :));
    physical_node_mask = false(num_nodes, 1);
    physical_node_mask(physical_nodes) = true;
end

if isempty(node_multiplier)
    node_multiplier = ones(num_nodes, 1);
else
    node_multiplier = double(node_multiplier(:));
    if numel(node_multiplier) ~= num_nodes
        error('wdn:EntropyMultiplierSize', 'Node multiplier length mismatch.');
    end
end

oriented_links = links;
reverse = flows < 0;
oriented_links(reverse, :) = fliplr(oriented_links(reverse, :));
flow_magnitudes = abs(flows);

external_supply = zeros(num_nodes, 1);
external_supply(physical_nodes) = max(-demands(physical_nodes), 0);

% Collapse each excluded EPANET supply adapter onto its downstream physical node.
for k = model.entropy_excluded_link_indices(:)'
    downstream = oriented_links(k, 2);
    if physical_node_mask(downstream)
        external_supply(downstream) = external_supply(downstream) + flow_magnitudes(k);
    end
end

total_supply = sum(external_supply);
if total_supply <= eps
    error('wdn:EntropyNoInflow', 'Entropy is undefined because total physical inflow is zero.');
end

source_nodes = find(external_supply > 0);
source_probabilities = external_supply(source_nodes) / total_supply;
source_entropy = -sum(source_probabilities .* log(source_probabilities) .* ...
    node_multiplier(source_nodes));

node_entropy = zeros(num_nodes, 1);
throughflow = zeros(num_nodes, 1);
for n = physical_nodes(:)'
    outgoing = physical_links(oriented_links(physical_links, 1) == n);
    positive_demand = max(demands(n), 0);
    throughflow(n) = sum(flow_magnitudes(outgoing)) + positive_demand;
    if throughflow(n) <= eps
        continue;
    end

    probabilities = [flow_magnitudes(outgoing); positive_demand] / throughflow(n);
    probabilities = probabilities(probabilities > 0);
    arrival_weight = throughflow(n) / total_supply * node_multiplier(n);
    node_entropy(n) = -arrival_weight * sum(probabilities .* log(probabilities));
end

entropy_value = source_entropy + sum(node_entropy);
details.total_supply = total_supply;
details.external_supply = external_supply;
details.throughflow = throughflow;
details.source_entropy = source_entropy;
details.node_entropy = node_entropy;
end
