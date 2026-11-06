function weighting=balerma_connected_branch_weights(cfg)
%BALERMA_CONNECTED_BRANCH_WEIGHTS Undirected branch hops from four sources.
% The reservoirs remain physical fixed-head sources in the hydraulic INP.
% Weights use input topology and base demands only, so flow reversals during
% failures do not change the source-distance definition.
assert(isequal(sort(string(cfg.source_node_ids(:))), ...
    sort(["38";"43";"44";"88"])), ...
    'Balerma branch weights require the four connected reservoirs');
wdn.setup_toolkit(cfg);
[d,net]=wdn.open_network(cfg);
release=onCleanup(@()d.unload());
categories=d.getNodeBaseDemands;
base_demands=zeros(numel(net.node_ids),1);
for k=1:numel(categories)
    base_demands=base_demands+double(categories{k}(:));
end
weighting=wdn.topology_branch_hop_weights(net.node_ids, ...
    double(net.link_nodes),net.design_link_indices,base_demands, ...
    string(cfg.source_node_ids(:)));
weighting.physical_source_entries=cfg.source_node_ids;
weighting.weight_function='1/(1+b)';
weighting.distance_definition='undirected topology, four physical reservoirs';
clear release d
end
