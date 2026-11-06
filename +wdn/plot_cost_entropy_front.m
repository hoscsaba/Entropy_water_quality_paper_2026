function plot_cost_entropy_front(result, cfg, output_file)
%PLOT_COST_ENTROPY_FRONT Cost--branching-hop archive with two Cl encodings.

if ~strcmp(result.network_id, cfg.id) || ...
        ~isequal(string(result.objectives), ["cost", "branch_hop_weighted_entropy"])
    error('wdn:ResultObjectiveMismatch', ...
        'Expected an Anytown cost--branching-hop-entropy Pareto result.');
end
if any(result.max_constraint_violation > cfg.ga.constraint_tolerance)
    error('wdn:InvalidMultiobjectiveResult', ...
        'Cannot plot a Pareto set that contains infeasible designs.');
end

cost_million = result.cost(:) / 1e6;
branch_hop_entropy = result.branch_hop_entropy(:);
chlorine_objective = result.chlorine_concentration(:);
chlorine_entropy = result.chlorine_entropy(:);

entropy_min = min(chlorine_entropy);
entropy_max = max(chlorine_entropy);
entropy_fraction = (chlorine_entropy - entropy_min) ./ ...
    max(entropy_max - entropy_min, eps);
% A mildly nonlinear scale separates low and high chlorine-entropy designs
% more clearly while retaining a visible minimum marker area.
marker_area_min = 20;
marker_area_max = 240;
marker_area = marker_area_min + (marker_area_max - marker_area_min) * ...
    entropy_fraction.^1.45;

fig = figure('Color', 'w', 'Position', [100 100 1040 700]);
ax = axes(fig); hold(ax, 'on');
plot(ax, cost_million, branch_hop_entropy, '-', ...
    'Color', [0.32 0.32 0.32], 'LineWidth', 1.25, ...
    'HandleVisibility', 'off');
scatter(ax, cost_million, branch_hop_entropy, marker_area, ...
    chlorine_objective, 'filled', 'MarkerEdgeColor', 'k', ...
    'LineWidth', 0.75, 'HandleVisibility', 'off');
colormap(fig, turbo);
cb = colorbar(ax);
cb.Label.String = 'Chlorine concentration objective, \Sigma C_i^2 [(mg/L)^2]';

legend_handles(1) = plot(ax, NaN, NaN, 'o', 'LineStyle', 'none', ...
    'MarkerSize', 4.5, 'MarkerFaceColor', [0.72 0.72 0.72], ...
    'MarkerEdgeColor', 'k');
legend_handles(2) = plot(ax, NaN, NaN, 'o', 'LineStyle', 'none', ...
    'MarkerSize', 13.5, 'MarkerFaceColor', [0.72 0.72 0.72], ...
    'MarkerEdgeColor', 'k');
legend_labels = {sprintf('Cl entropy %.2f', entropy_min), ...
    sprintf('Cl entropy %.2f', entropy_max)};
legend(ax, legend_handles, legend_labels, 'Location', 'southeast', ...
    'FontSize', 13, 'Box', 'on');

xlabel(ax, 'Cost [10^6 relative cost units]');
ylabel(ax, 'Branching-hop entropy [-]');
title(ax, 'Anytown cost versus branching-hop entropy', 'FontSize', 17);
grid(ax, 'on'); box(ax, 'on');
ax.FontSize = 15;
cb.FontSize = 14;
cb.Label.FontSize = 15;
ax.LineWidth = 0.8;

cost_span = max(cost_million) - min(cost_million);
entropy_span = max(branch_hop_entropy) - min(branch_hop_entropy);
if cost_span <= eps, cost_span = 1; end
if entropy_span <= eps, entropy_span = 1; end
xlim(ax, [min(cost_million) - 0.04*cost_span, ...
    max(cost_million) + 0.04*cost_span]);
ylim(ax, [min(branch_hop_entropy) - 0.06*entropy_span, ...
    max(branch_hop_entropy) + 0.08*entropy_span]);

exportgraphics(fig, output_file, 'Resolution', cfg.plot.resolution);
[output_dir, output_name] = fileparts(output_file);
exportgraphics(fig, fullfile(output_dir, [output_name '.svg']), ...
    'ContentType', 'vector');
close(fig);
end
