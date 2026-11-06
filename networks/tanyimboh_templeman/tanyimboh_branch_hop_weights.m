function weighting = tanyimboh_branch_hop_weights(cfg)
%TANYIMBOH_BRANCH_HOP_WEIGHTS Frozen source-distance weights for the TT graph.
% Physical node 1 receives the fixed-head reservoir's flow through adapter
% P_input_2; node 2 supplies the prescribed negative demand. The adapter is
% excluded from the eight-pipe service graph. Flow direction is ignored, as
% in the Anytown and Balerma branch-hop calculations. Branching includes a
% demand exit. This function solves no hydraulics.
wdn.setup_toolkit(cfg);
[d,net] = wdn.open_network(cfg);
release = onCleanup(@() d.unload());
categories = d.getNodeBaseDemands;
base_demands = zeros(numel(net.node_ids),1);
for k = 1:numel(categories)
    base_demands = base_demands + double(categories{k}(:));
end
roots = ["1";"2"];
weighting = wdn.topology_branch_hop_weights(net.node_ids, ...
    double(net.link_nodes),net.design_link_indices,base_demands,roots);
weighting.physical_source_entries = cellstr(roots);
weighting.weight_function = '1/(1+b)';
weighting.distance_definition = ...
    'undirected physical pipes, branching demand exits, source entries 1 and 2';
clear release d
end
