function ranking = rank_pipes(cfg)
%RANK_PIPES Rank physical design pipes about a feasible reference design.

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
old_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(old_dir));

has_pressure_anchors = isfield(cfg, 'pressure_anchor_node_ids') && ...
    ~isempty(cfg.pressure_anchor_node_ids);
if has_pressure_anchors
    x_ref = wdn.pressure_anchor_reference(cfg, model);
    reference_method = 'pressure_anchor_reference';
else
    x_ref = model.original_full_diameters(model.design_link_indices);
    reference_method = 'original_feasible_design';
end
[c_ref, ceq_ref] = wdn.pressure_constraints(x_ref, d, cfg, model);
reference_violation = max([0; c_ref(:); abs(ceq_ref(:))]);
if reference_violation > cfg.ga.constraint_tolerance
    error('wdn:RankingReferenceInfeasible', ...
        'Pressure-anchor reference violates constraints by %.6g.', reference_violation);
end

wdn.apply_design(d, x_ref, cfg, model);
d.solveCompleteHydraulics;
flow_raw = double(d.getLinkFlows);
flow_score = abs(flow_raw(model.design_link_indices));
[entropy_ref, entropy_details] = wdn.flow_entropy(d, model, []);
pressure_raw = double(d.getNodePressure);
pressure_ref = pressure_raw(model.pressure_node_indices);
links = double(d.getLinkNodesIndex);
design_nodes = links(model.design_link_indices, :);
nodal_score = entropy_details.node_entropy(design_nodes(:, 1)) + ...
    entropy_details.node_entropy(design_nodes(:, 2));
lengths = model.link_lengths(model.design_link_indices);
volume_score = pi / 4 .* x_ref(:).^2 .* lengths(:);

n = numel(x_ref);
pressure_score = zeros(n, 1);
entropy_score = zeros(n, 1);
fraction = cfg.ranking.perturbation_fraction;
for j = 1:n
    response_pressure = 0;
    response_entropy = 0;
    for sign_value = [-1, 1]
        x = x_ref;
        x(j) = min(cfg.maximum_diameter, max(cfg.minimum_diameter, ...
            x_ref(j) * (1 + sign_value * fraction)));
        wdn.apply_design(d, x, cfg, model);
        d.solveCompleteHydraulics;
        p = double(d.getNodePressure);
        response_pressure = response_pressure + ...
            sum(abs(p(model.pressure_node_indices) - pressure_ref));
        h = wdn.flow_entropy(d, model, []);
        response_entropy = response_entropy + abs(h - entropy_ref);
    end
    pressure_score(j) = response_pressure;
    entropy_score(j) = response_entropy;
end

criterion_keys = ["flow_rate", "pressure_sensitivity", "nodal_entropy", ...
    "entropy_sensitivity", "volume"];
criterion_labels = ["Flow rate", "Pressure sensitivity", "Nodal entropy", ...
    "Entropy sensitivity", "Volume"];
scores = [flow_score(:), pressure_score, nodal_score(:), ...
    entropy_score, volume_score(:)];
link_ids = string(cfg.design_link_ids(:));
link_numbers = str2double(link_ids);
orders = zeros(n, numel(criterion_keys));
normalized_scores = zeros(size(scores));
for q = 1:numel(criterion_keys)
    [~, order] = sortrows([-scores(:, q), link_numbers], [1, 2]);
    orders(:, q) = order;
    maximum_score = max(scores(:, q));
    if maximum_score > 0
        normalized_scores(:, q) = 100 * scores(:, q) / maximum_score;
    end
end

ranking.network_id = cfg.id;
ranking.reference_method = reference_method;
ranking.reference_design = x_ref(:)';
ranking.reference_entropy = entropy_ref;
ranking.reference_pressures = pressure_ref(:)';
ranking.reference_constraint_violation = reference_violation;
ranking.design_link_ids = cellstr(link_ids);
ranking.criterion_keys = cellstr(criterion_keys);
ranking.criterion_labels = cellstr(criterion_labels);
ranking.scores = scores;
ranking.normalized_scores_percent = normalized_scores;
ranking.orders = orders;
ranking.ordered_link_ids = cell(n, numel(criterion_keys));
for q = 1:numel(criterion_keys)
    ranking.ordered_link_ids(:, q) = cellstr(link_ids(orders(:, q)));
end
ranking.created_at = datetime('now', 'TimeZone', 'local');
end
