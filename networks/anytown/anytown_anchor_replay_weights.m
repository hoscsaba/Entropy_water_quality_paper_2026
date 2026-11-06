function weighting=anytown_anchor_replay_weights(cfg)
%ANYTOWN_ANCHOR_REPLAY_WEIGHTS Frozen undirected 1/(1+b) branch-hop weights.
% Future failure supply entries at 60/160 count as topological roots even
% though the reservoirs have zero flow during nominal optimization.
wdn.setup_toolkit(cfg);
[d,net]=wdn.open_network(cfg);
release=onCleanup(@()d.unload());
categories=d.getNodeBaseDemands;
base_demands=zeros(numel(net.node_ids),1);
for k=1:numel(categories)
    base_demands=base_demands+double(categories{k}(:));
end
roots=["20";"60";"160"];
weighting=wdn.topology_branch_hop_weights(net.node_ids, ...
    double(net.link_nodes),net.design_link_indices,base_demands,roots);
weighting.physical_source_entries=cellstr(roots);
weighting.weight_function='1/(1+b)';
clear release d
end
