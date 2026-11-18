function [value, details] = staci_chlorine_entropy(staci, cfg, chlorine_mgL)
%STACI_CHLORINE_ENTROPY Entropy of local chlorine-mass splitting.
% For every physical outgoing pipe, the branch mass rate is Q times the
% stationary residual at its downstream end. A consumer withdrawal is a
% separate branch with its local nodal residual. We normalize these mass
% rates at each junction before computing Shannon entropy. This is distinct
% from multiplying hydraulic entropy by the junction concentration: pipe
% travel time and decay can change the relative outlet probabilities.
% Chlorine_mgL must follow staci.nodeResults().id order.

nodes = staci.nodeResults();
links = staci.linkResults();
node_ids = string(nodes.id(:));
chlorine = double(chlorine_mgL(:));
n = numel(node_ids);
assert(numel(chlorine)==n && all(isfinite(chlorine)) && ...
    all(chlorine>=-1e-9), 'Chlorine vector must follow STACI node order');
chlorine = max(chlorine,0);

% Reuse the same physical-service boundary accounting as hydraulic entropy.
[~, hydraulic] = wdn.staci_flow_entropy(staci,cfg,[]);
supply_mass = hydraulic.external_supply(:).*chlorine;
total_source_mass = sum(supply_mass);
assert(total_source_mass>0,'No positive chlorine mass enters the service graph');
source_share = supply_mass(supply_mass>0)/total_source_mass;
source_entropy = -sum(source_share.*log(source_share));

link_ids = string(links.id(:));
physical = ismember(link_ids,string(cfg.design_link_ids(:)));
from = string(links.from_node(physical));
to = string(links.to_node(physical));
[found_from,from_idx] = ismember(from,node_ids);
[found_to,to_idx] = ismember(to,node_ids);
assert(all(found_from & found_to),'Physical pipe endpoint is missing');
flow = double(links.flow_rate_m3s(physical));
reverse = flow<0;
upstream = from_idx;
downstream = to_idx;
upstream(reverse) = to_idx(reverse);
downstream(reverse) = from_idx(reverse);
q = abs(flow);

% Pipe outlet mass reaches the downstream node after first-order decay.
pipe_mass = q.*chlorine(downstream);
consumer_q = max(double(nodes.demand_m3s(:)),0);
consumer_mass = consumer_q.*chlorine;
outgoing_mass = accumarray(upstream,pipe_mass,[n,1]) + consumer_mass;
local_entropy = zeros(n,1);
active_pipe = pipe_mass>0 & outgoing_mass(upstream)>0;
if any(active_pipe)
    p = pipe_mass(active_pipe)./outgoing_mass(upstream(active_pipe));
    local_entropy = local_entropy + accumarray(upstream(active_pipe), ...
        -p.*log(p),[n,1]);
end
active_consumer = consumer_mass>0 & outgoing_mass>0;
if any(active_consumer)
    p = consumer_mass(active_consumer)./outgoing_mass(active_consumer);
    local_entropy(active_consumer) = local_entropy(active_consumer) ...
        - p.*log(p);
end

% Chlorine mass arriving at a junction is approximated by its mixed nodal
% residual times its complete physical outflow (including local demand).
% This is the mass-throughput weight in Eq. (chlorine-weight) of the paper.
node_weight = hydraulic.throughflow(:).*chlorine/total_source_mass;
value = source_entropy + sum(node_weight.*local_entropy);
assert(isfinite(value),'Non-finite chlorine-splitting entropy');
if nargout>1
    details.source_entropy = source_entropy;
    details.source_mass_rate = total_source_mass;
    details.node_entropy = node_weight.*local_entropy;
    details.local_entropy = local_entropy;
    details.node_weight = node_weight;
    details.outgoing_mass_rate = outgoing_mass;
    details.pipe_mass_rate = pipe_mass;
    details.pipe_upstream = upstream;
    details.pipe_downstream = downstream;
end
end
