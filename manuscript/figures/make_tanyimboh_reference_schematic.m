function make_tanyimboh_reference_schematic
%MAKE_TANYIMBOH_REFERENCE_SCHEMATIC Reproduce the Case-A reference graph.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
output_dir = fullfile(root, 'networks', 'tanyimboh_templeman', 'figures');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Node coordinates and directed links follow Case A in the reference table.
xy = [1 1; -1 1; 1 0; -1 0; 1 -1; -1 -1];
directed_links = [1 3; 1 4; 2 3; 2 4; 3 4; 3 5; 4 6; 5 6];

fig = figure('Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 14 12]);
ax = axes(fig); hold(ax, 'on');

for k = 1:size(directed_links, 1)
    a = directed_links(k, 1);
    b = directed_links(k, 2);
    p1 = xy(a, :);
    p2 = xy(b, :);
    plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], 'k-', 'LineWidth', 2.2);

    % A short centered quiver gives an unambiguous arrow without covering nodes.
    start_point = p1 + 0.38 * (p2 - p1);
    arrow_vector = 0.24 * (p2 - p1);
    quiver(ax, start_point(1), start_point(2), ...
        arrow_vector(1), arrow_vector(2), 0, 'Color', 'k', ...
        'LineWidth', 2.0, 'MaxHeadSize', 1.8);
end

scatter(ax, xy(:,1), xy(:,2), 130, 'k', 'filled');
node_offsets = [0.14 0.10; -0.20 0.10; 0.14 0.05; -0.20 0.05; ...
    0.14 -0.02; -0.20 -0.02];
for n = 1:6
    text(ax, xy(n,1) + node_offsets(n,1), xy(n,2) + node_offsets(n,2), ...
        sprintf('%d', n), 'FontSize', 15, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
end

% External inflows and demands; numbers are reference-problem flow rates.
external = [1 0 1 20; 2 0 1 35; 3 -0.62 -0.52 15; ...
    4 -0.62 -0.52 25; 5 -0.62 -0.52 5; 6 -0.62 -0.52 10];
for k = 1:size(external, 1)
    n = external(k, 1);
    direction = external(k, 2:3);
    if n <= 2
        start_point = xy(n,:) + direction;
        arrow_vector = -0.68 * direction;
        label_point = start_point + [0, 0.10];
    else
        start_point = xy(n,:) - 0.05 * direction;
        arrow_vector = 0.70 * direction;
        label_point = start_point + arrow_vector + 0.10 * direction;
    end
    quiver(ax, start_point(1), start_point(2), arrow_vector(1), ...
        arrow_vector(2), 0, 'Color', [0.15 0.15 0.15], ...
        'LineWidth', 2.0, 'MaxHeadSize', 1.4);
    text(ax, label_point(1), label_point(2), sprintf('%g', external(k,4)), ...
        'FontSize', 15, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

text(ax, 0, 1.64, 'external inflow', 'FontSize', 14, ...
    'HorizontalAlignment', 'center');
text(ax, 0, -1.68, 'consumer demand', 'FontSize', 14, ...
    'HorizontalAlignment', 'center');
axis(ax, 'equal');
xlim(ax, [-1.95 1.95]);
ylim(ax, [-1.85 2.30]);
axis(ax, 'off');

exportgraphics(fig, fullfile(output_dir, 'reference_schematic.png'), ...
    'Resolution', 600);
exportgraphics(fig, fullfile(output_dir, 'reference_schematic.svg'), ...
    'ContentType', 'vector');
close(fig);

generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end
copyfile(fullfile(output_dir, 'reference_schematic.png'), ...
    fullfile(generated_dir, 'tanyimboh_schemtic.png'), 'f');
copyfile(fullfile(output_dir, 'reference_schematic.svg'), ...
    fullfile(generated_dir, 'tanyimboh_schemtic.svg'), 'f');
end
