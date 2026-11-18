function [violation, consumer_ids, minimum_mgL] = consumer_chlorine_constraint(nodes, quality, numerical_guard_mgL)
%CONSUMER_CHLORINE_CONSTRAINT Common nominal chlorine floor for every search.
% Include junctions whose demand exceeds the flow in a 10 mm pipe at
% 1 cm/s. Reservoirs and negligible-demand nodes are excluded. STACI
% concentrations are kg/m^3; the paper's residual floor is 0.2 mg/L.
threshold_m3s = pi/4 * 0.010^2 * 0.01;
if nargin<3 || isempty(numerical_guard_mgL)
    numerical_guard_mgL=0;
end
assert(isscalar(numerical_guard_mgL) && ...
    isfinite(numerical_guard_mgL) && numerical_guard_mgL>=0);
ids = string(nodes.id(:));
consumer_ids = ids(double(nodes.demand_m3s(:)) > threshold_m3s);
assert(~isempty(consumer_ids), 'No material-demand consumers found');
[found, index] = ismember(consumer_ids, string(quality.node_ids(:)));
assert(all(found), 'Material-demand consumer missing from quality result');
chlorine_mgL = 1000 * double(quality.node_concentration_kgm3(index));
assert(all(isfinite(chlorine_mgL)), 'Non-finite consumer chlorine');
minimum_mgL = min(chlorine_mgL);
violation = (0.2+numerical_guard_mgL) - chlorine_mgL(:);
end
