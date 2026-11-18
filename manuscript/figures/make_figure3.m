function make_figure3
%MAKE_FIGURE3 Six saved TT designs in the manuscript's 3-by-2 arrangement.
% This only redraws the existing optimized designs; it runs no GA.
% Signed pipe flows follow the directions in the reference schematic.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir = fullfile(root, 'networks', 'tanyimboh_templeman');
addpath(network_dir);
cfg = network_config(network_dir);
cfg.inp_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');
cfg.results_dir = fullfile(network_dir,'results_staci_10_120_clsplit_v2');
cfg.figures_dir = fullfile(network_dir,'figures_staci_10_120_clsplit_v2');
cfg.plot.matrix_objectives = {'cost','hydraulic_entropy', ...
    'branch_hop_weighted_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
cfg.plot.matrix_titles = {'Cost','Hydraulic entropy','Branch-hop entropy', ...
    'Cl concentration','Cl entropy','Todini index'};
% Match the main-text comparison: one source-to-zero chlorine scale.
cfg.plot.chlorine_limits = [0,cfg.source_chlorine];
% Leave enough room for the left-hand diameter labels in portrait panels.
cfg.plot.axis_padding = 0.34;
cfg.plot.x_padding = 1.05;
cfg.plot.y_padding = 0.46;
cfg.plot.force_canvas_bounds = true;
cfg.plot.print_full_canvas = true;
% Display-only horizontal stretch makes the 3-by-2 matrix legible. The
% hydraulic INP, link lengths, saved flows, and optimization stay unchanged.
cfg.plot.display_x_node_ids = ["2","1","4","3","6","5"];
cfg.plot.display_x_positions = [0,2,0,2,0,2];
cfg.plot.diameter_label_font_size = 19;
cfg.plot.panel_title_font_size = 18;
cfg.plot.colorbar_font_size = 17;
% Equal-length arrows beside each link show the actual signed flow direction.
% P8 is the lowermost horizontal edge in the display (length 2 units).
% Negligible flows are left without an arrow.
cfg.plot.show_flow_arrows = true;
cfg.plot.flow_arrow_min_m3h = 0.05;
cfg.plot.flow_arrow_offset = 0.075;
cfg.plot.flow_arrow_reference_link_id = 'P8';
cfg.plot.flow_arrow_reference_fraction = 0.20;
cfg.plot.flow_label_decimals = 1;
cfg.plot.rotate_diagonal_edge_labels = true;
% Show both actual source inflows from each saved hydraulic solution.
% Node 1 is the fixed-head reservoir; node 2 is the fixed-flow inlet.
% Horizontal arrows enter from outside the network on opposite sides.
cfg.plot.source_inlet_arrow_node_ids = ["2","1"];
% In S3 alone, dashes denote flows displayed as 0.0 m^3/h (one decimal),
% rather than the diameter <= 1 in convention used in other figures.
cfg.plot.dash_zero_display_flow_only = true;
% In the displayed coordinates, put vertical-link labels outside the columns,
% horizontal-link labels below the pipes, and diagonal labels above the
% links near their source ends. Arrows sit farther down each pipe.
cfg.plot.diameter_label_fraction_by_link.P2 = 0.20;
cfg.plot.diameter_label_fraction_by_link.P3 = 0.20;
cfg.plot.diameter_label_offset_by_link.P1 = [0.60,0];
cfg.plot.diameter_label_offset_by_link.P4 = [-0.60,0];
cfg.plot.diameter_label_offset_by_link.P6 = [0.60,0];
cfg.plot.diameter_label_offset_by_link.P7 = [-0.60,0];
cfg.plot.diameter_label_offset_by_link.P5 = [0,-0.24];
cfg.plot.diameter_label_offset_by_link.P8 = [0,-0.24];
cfg.plot.diameter_label_offset_by_link.P2 = [-0.11,0.25];
cfg.plot.diameter_label_offset_by_link.P3 = [0.11,0.25];
wdn.setup_toolkit(cfg);

if ~exist(cfg.figures_dir, 'dir')
    mkdir(cfg.figures_dir);
end

output_file = fullfile(cfg.figures_dir, 'figure3.png');
wdn.plot_objective_matrix(cfg, output_file, 'chlorine', 'flow_m3h_signed', ...
    struct('layout_shape',[3,2]));
generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end
copyfile(output_file, fullfile(generated_dir, 'figure3.png'), 'f');
copyfile(fullfile(cfg.figures_dir,'figure3.svg'), ...
    fullfile(generated_dir,'figure3.svg'),'f');
fprintf('Figure written to %s\n', output_file);
end
