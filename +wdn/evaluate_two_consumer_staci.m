function state = evaluate_two_consumer_staci(staci, diameter_mm)
%EVALUATE_TWO_CONSUMER_STACI Evaluate the paper's four-pipe loop in memory.
% The common INP supplies 0.8 and 1.3 L/s and 1 mg/L source chlorine.
link_ids = ["P0";"P1";"P2";"P3"];
node_ids = ["S";"J";"D1";"D2"];
staci.setLinkProperty(link_ids,'diameter_m',double(diameter_mm(:))/1000);
status = staci.solveHydraulics();
assert(status.converged,'STACI mini-example hydraulics did not converge');
nodes = staci.nodeResults();
links = staci.linkResults();
quality = staci.solveSteadyQuality('chemical');
[ok_node, ni] = ismember(node_ids,string(nodes.id(:)));
[ok_link, li] = ismember(link_ids,string(links.id(:)));
[ok_quality, qi] = ismember(node_ids,string(quality.node_ids(:)));
assert(all(ok_node) && all(ok_link) && all(ok_quality));
state.flow_Lps = double(links.flow_rate_m3s(li(:)))' * 1000;
state.head_m = double(nodes.total_head_m(ni(:)))';
state.chlorine_mgL = ...
    double(quality.node_concentration_kgm3(qi(:)))' * 1000;
cfg.design_link_ids = cellstr(link_ids);
state.hydraulic_entropy = wdn.staci_flow_entropy(staci,cfg,[]);
chlorine_ordered = zeros(numel(nodes.id),1);
chlorine_ordered(ni(:)) = state.chlorine_mgL(:);
[state.chlorine_entropy,detail] = ...
    wdn.staci_flow_entropy(staci,cfg,chlorine_ordered);
state.chlorine_node_entropy = detail.node_entropy(ni(:))';
[~,detail] = wdn.staci_flow_entropy(staci,cfg,[]);
state.hydraulic_node_entropy = detail.node_entropy(ni(:))';
assert(abs(sum(state.chlorine_node_entropy) - ...
    state.chlorine_entropy) < 1e-9);
end
