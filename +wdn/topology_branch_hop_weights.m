function result = topology_branch_hop_weights(node_ids, link_nodes, ...
        physical_link_indices, base_demands, source_node_ids)
%TOPOLOGY_BRANCH_HOP_WEIGHTS Branch distances without hydraulic flow directions.
% The physical-pipe graph is traversable in either direction. At an interior
% junction, an incoming path has an alternative exit when the junction has
% at least three physical pipes, or two pipes plus positive demand. An entry
% source has no incoming physical pipe, so two exits already make it a branch.
% Crossing an edge adds one hop if its origin is a branch. The minimum count
% from any listed source defines w_i = 1/(1+b_i). Source IDs can include a
% reservoir and the downstream connection of a supply pump. A source with no
% physical-pipe edge has weight one locally but cannot shorten other paths.
%
% Only topology and input base demands are used. No hydraulics are solved.

node_ids = string(node_ids(:));
source_node_ids = string(source_node_ids(:));
base_demands = double(base_demands(:));
assert(numel(base_demands) == numel(node_ids), 'Demand/node count mismatch');
assert(size(link_nodes,2) == 2, 'Link endpoints must have two columns');
[found, roots] = ismember(source_node_ids, node_ids);
assert(all(found) && ~isempty(roots), 'Supply node missing');

edges = double(link_nodes(physical_link_indices,:));
n = numel(node_ids);
assert(all(edges(:) >= 1 & edges(:) <= n), 'Invalid pipe endpoint');
u = edges(:,1); v = edges(:,2);
degree = accumarray([u;v], 1, [n,1]);
demand_exit = base_demands > 0;
is_branch = degree + double(demand_exit) >= 3;
is_branch(roots) = degree(roots) + double(demand_exit(roots)) >= 2;

% Directed arcs in both directions encode an undirected physical topology.
% Arc cost depends only on whether the node being left is a branch.
arcs = digraph([u;v], [v;u], ...
    double(is_branch([u;v])), n);
branch_hops = min(distances(arcs, roots), [], 1)';
physical_nodes = unique(edges(:));
assert(all(isfinite(branch_hops(physical_nodes))), ...
    'A physical junction is disconnected from all listed supplies');
weights = zeros(n,1);
reachable = isfinite(branch_hops);
weights(reachable) = 1 ./ (1 + branch_hops(reachable));

result = struct('node_ids',{cellstr(node_ids)}, ...
    'source_node_ids',{cellstr(source_node_ids)}, ...
    'branch_hops',branch_hops,'weights',weights, ...
    'physical_degree',degree,'base_demands',base_demands, ...
    'demand_exit',demand_exit,'is_branch',is_branch, ...
    'physical_link_indices',physical_link_indices(:));
end
