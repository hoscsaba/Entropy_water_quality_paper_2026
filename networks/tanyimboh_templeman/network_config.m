function cfg = network_config(network_dir)
%NETWORK_CONFIG Settings for the 8-pipe Tanyimboh–Templeman benchmark.

if nargin == 0
    network_dir = fileparts(mfilename('fullpath'));
end
project_root = fileparts(fileparts(network_dir));

cfg.id = 'tanyimboh_templeman';
cfg.inp_file = fullfile(network_dir, 'input', 'network_staci_fixed_load.inp');
cfg.results_dir = fullfile(network_dir, 'results_staci_10_120_clsplit_v2');
cfg.figures_dir = fullfile(network_dir, 'figures_staci_10_120_clsplit_v2');
cfg.runtime_dir = fullfile(network_dir, 'runtime');
cfg.toolkit_dir = fullfile(project_root, 'third_party', ...
    'epanet_matlab_toolkit');
toolkit_override = getenv('WDS_EPANET_TOOLKIT');
if ~isempty(toolkit_override)
    cfg.toolkit_dir = toolkit_override;
end
native_library = fullfile(project_root, 'third_party', 'epanet22_arm64', 'libepanet2');
cfg.toolkit_patch_dir = fullfile(project_root, 'third_party', ...
    'epanet_matlab_toolkit_patch');
if ismac && isfile(strcat(native_library, '.dylib'))
    cfg.epanet_library = native_library;
else
    cfg.epanet_library = '';
end

% The eight physical pipes are the only design and failure variables.
% Node 1 itself is the 50-m source reservoir, with no connector pipe.
cfg.design_link_ids = {'P1','P4','P7','P6','P2','P3','P8','P5'};
cfg.fixed_link_diameters = struct();
cfg.entropy_excluded_link_ids = {};
cfg.minimum_diameter = 2.54; % 0.1 in, expressed in mm for this network
cfg.maximum_diameter = 1625.6; % 64 in
cfg.numeric_tolerance = 1e-3; % EPANET stores diameters as single precision

% Only positive-demand consumer nodes are pressure/quality assessment nodes.
cfg.pressure_node_ids = {'2','3','4','5','6'};
cfg.quality_node_ids = {'4','3','6','5'};
cfg.minimum_pressure = 10;
cfg.maximum_pressure = 120;

cfg.cost_coefficient = 230;
cfg.cost_exponent = 0.48;
cfg.quality_duration_hours = 48;
cfg.quality_step_hours = 48;
cfg.bulk_reaction_coefficient = -1;
cfg.source_chlorine = 1;
cfg.source_node_ids = {'1','2'};

% Reservoir node 1 and the node-2 injection remain in the input during
% every physical-pipe outage; neither supply boundary is failed.
cfg.stress.failed_link_ids = cfg.design_link_ids;
cfg.stress.node_ids = cfg.quality_node_ids;
cfg.stress.minimum_chlorine = 0.2;
% A component containing only the fixed-flow node-2 inlet has no fixed
% pressure datum. Count all its consumer demand as unserved after isolation.
cfg.stress.require_fixed_head_source = true;

cfg.objectives = {'cost','hydraulic_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
cfg.ga.random_seed = 1993;
cfg.ga.population_size = 100;
cfg.ga.max_generations = 10000;
cfg.ga.max_stall_generations = 150;
cfg.ga.function_tolerance = 1e-6;
cfg.ga.constraint_tolerance = 1e-5;
cfg.ga.use_hybrid_patternsearch = true;
cfg.ga.display = 'final';

% Eight physical pipes permit a complete nested ranking study.
cfg.ranking.perturbation_fraction = 0.10;
cfg.ranking.k_values = 0:8;
cfg.ranking.max_generations = 100;
cfg.ranking.max_stall_generations = 30;
cfg.ranking.cache_dir = fullfile(cfg.results_dir,'ranking_cache');
cfg.ranking.display = 'final';
cfg.ranking.figure_basename = 'tanyimboh_ranking_objectives';
cfg.ranking.chlorine_figure_basename = ...
    'tanyimboh_chlorine_ranking_objectives';

cfg.plot.minimum_line_width = 0.8;
cfg.plot.maximum_line_width = 7;
cfg.plot.fixed_link_width = 3;
cfg.plot.minimum_diameter_tolerance = 0.15;
cfg.plot.dashed_diameter_threshold = 25.4; % 1 in in the plot's mm units
cfg.plot.node_size = 95;
cfg.plot.diameter_label_font_size = 14;
cfg.plot.axis_padding = 0.18;
cfg.plot.pressure_label = 'Pressure [m]';
cfg.plot.diameter_label_link_ids = cfg.design_link_ids;
cfg.plot.diameter_label_fraction_by_link = struct('P2', 0.25, 'P3', 0.25);
cfg.plot.diameter_label_offset_by_link = struct( ...
    'P1', [0.12, 0], 'P4', [-0.12, 0], ...
    'P7', [-0.12, 0], 'P6', [0.12, 0], ...
    'P2', [0.03, 0.03], 'P3', [-0.03, 0.03], ...
    'P8', [0, -0.10], 'P5', [0, -0.10]);
cfg.plot.resolution = 600;
end
