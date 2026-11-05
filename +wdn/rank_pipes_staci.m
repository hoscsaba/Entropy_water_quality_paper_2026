function ranking = rank_pipes_staci(cfg, input_file)
%RANK_PIPES_STACI Five hydraulic rankings on one STACI fixed-load model.
st = StaciModel(input_file);
cleanup = onCleanup(@() st.release());
design_ids = string(cfg.design_link_ids(:));
if strcmp(cfg.id, 'anytown')
    scale = 0.0254;
    length_scale = 1/0.3048;
else
    scale = 0.001;
    length_scale = 1;
end
x_original = double(st.getLinkProperty(design_ids, 'diameter_m')) / scale;
if isfield(cfg, 'pressure_anchor_node_ids') && ...
        ~isempty(cfg.pressure_anchor_node_ids)
    x_ref = x_original + cfg.ga.feasible_interpolation_to_upper * ...
        (cfg.maximum_diameter - x_original);
    reference_method = 'staci_pressure_anchor_interpolation';
else
    x_ref = x_original;
    reference_method = 'staci_original_design';
end
st.setLinkProperty(design_ids, 'diameter_m', x_ref * scale);
status = st.solveHydraulics();
assert(status.converged, 'STACI ranking reference did not converge');
nodes = st.nodeResults(); links = st.linkResults();
node_ids = string(nodes.id(:));
link_ids = string(links.id(:));
[found_design, li] = ismember(design_ids, link_ids);
[found_pressure, pidx] = ismember(string(cfg.pressure_node_ids(:)), node_ids);
assert(all(found_design) && all(found_pressure), 'Ranking IDs missing');
flow_score = abs(double(links.flow_rate_m3s(li)));
[entropy_ref, details] = wdn.staci_flow_entropy(st, cfg, []);
pressure_ref = double(nodes.pressure_head_m(pidx));
if strcmp(cfg.id, 'anytown')
    pressure_checked = pressure_ref / (0.3048 * cfg.pressure_to_head);
else
    pressure_checked = pressure_ref;
end
reference_constraints = cfg.minimum_pressure - pressure_checked;
if isfinite(cfg.maximum_pressure)
    reference_constraints = [reference_constraints; ...
        pressure_checked - cfg.maximum_pressure];
end
if isfield(cfg, 'pressure_anchor_node_ids') && ...
        ~isempty(cfg.pressure_anchor_node_ids)
    [found_anchor, ai] = ismember(string(cfg.pressure_anchor_node_ids(:)), ...
        node_ids);
    assert(all(found_anchor), 'Reference anchor node missing');
    reference_constraints = [reference_constraints; ...
        abs(double(nodes.total_head_m(ai))/0.3048 - ...
        cfg.pressure_anchor_target_heads(:)) - ...
        cfg.pressure_anchor_head_tolerance];
end
reference_violation = max([0; reference_constraints(:)]);
from = string(links.from_node(li)); to = string(links.to_node(li));
[found_from, fi] = ismember(from, node_ids);
[found_to, ti] = ismember(to, node_ids);
assert(all(found_from) && all(found_to));
nodal_score = details.node_entropy(fi) + details.node_entropy(ti);
lengths = double(st.getLinkProperty(design_ids, 'length_m')) * length_scale;
volume_score = pi/4 * x_ref.^2 .* lengths;
n = numel(design_ids);
pressure_score = zeros(n, 1);
entropy_score = zeros(n, 1);
fraction = cfg.ranking.perturbation_fraction;
for j = 1:n
    for direction = [-1, 1]
        x = x_ref;
        x(j) = min(cfg.maximum_diameter, max(cfg.minimum_diameter, ...
            x_ref(j) * (1 + direction * fraction)));
        st.setLinkProperty(design_ids, 'diameter_m', x * scale);
        status = st.solveHydraulics();
        assert(status.converged, 'Ranking perturbation failed at pipe %s', ...
            design_ids(j));
        state = st.nodeResults();
        pressure_score(j) = pressure_score(j) + ...
            sum(abs(double(state.pressure_head_m(pidx)) - pressure_ref));
        entropy_score(j) = entropy_score(j) + ...
            abs(wdn.staci_flow_entropy(st, cfg, []) - entropy_ref);
    end
end
criteria = ["flow_rate", "pressure_sensitivity", "nodal_entropy", ...
    "entropy_sensitivity", "volume"];
labels = ["Flow rate", "Pressure sensitivity", "Nodal entropy", ...
    "Entropy sensitivity", "Volume"];
scores = [flow_score, pressure_score, nodal_score, ...
    entropy_score, volume_score];
numbers = str2double(design_ids);
orders = zeros(n, 5);
normalized = zeros(size(scores));
for q = 1:5
    [~, order] = sortrows([-scores(:,q), numbers], [1,2]);
    orders(:,q) = order;
    upper = max(scores(:,q));
    if upper > 0, normalized(:,q) = 100*scores(:,q)/upper; end
end
ranking.network_id = cfg.id;
ranking.model = 'staci_fixed_load';
ranking.reference_method = reference_method;
ranking.reference_design = x_ref(:)';
ranking.reference_entropy = entropy_ref;
ranking.reference_pressures = pressure_ref(:)';
ranking.reference_constraint_violation = reference_violation;
ranking.design_link_ids = cellstr(design_ids);
ranking.criterion_keys = cellstr(criteria);
ranking.criterion_labels = cellstr(labels);
ranking.scores = scores;
ranking.normalized_scores_percent = normalized;
ranking.orders = orders;
ranking.ordered_link_ids = cell(n,5);
for q = 1:5
    ranking.ordered_link_ids(:,q) = cellstr(design_ids(orders(:,q)));
end
ranking.created_at = datetime('now', 'TimeZone', 'local');
end
