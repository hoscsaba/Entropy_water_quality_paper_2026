function cfg = network_config(network_dir)
%NETWORK_CONFIG Reproducible settings for the Anytown benchmark.

if nargin == 0
    network_dir = fileparts(mfilename('fullpath'));
end
project_root = fileparts(fileparts(network_dir));

cfg.id = 'anytown';
cfg.inp_file = fullfile(network_dir, 'input', 'network_original.inp');
cfg.results_dir = fullfile(network_dir, 'results_staci');
cfg.figures_dir = fullfile(network_dir, 'figures_staci');
cfg.runtime_dir = fullfile(network_dir, 'runtime');
cfg.toolkit_dir = fullfile(project_root, 'third_party', ...
    'epanet_matlab_toolkit');
toolkit_override = getenv('WDS_EPANET_TOOLKIT');
if ~isempty(toolkit_override)
    cfg.toolkit_dir = toolkit_override;
end
native_library = fullfile(project_root, 'third_party', ...
    'epanet22_arm64', 'libepanet2');
cfg.toolkit_patch_dir = fullfile(project_root, 'third_party', ...
    'epanet_matlab_toolkit_patch');
if ismac && isfile(strcat(native_library, '.dylib'))
    cfg.epanet_library = native_library;
else
    cfg.epanet_library = '';
end

% Thirty-eight physical distribution pipes are design variables. Links 78
% and 80 are zero-flow pressure-anchor adapters; link 82 is the fixed pump.
cfg.design_link_ids = cellstr(string(2:2:76));
cfg.fixed_link_diameters = struct();
cfg.entropy_excluded_link_ids = {'78','80','82'};
cfg.minimum_diameter = 1;
cfg.maximum_diameter = 64;
cfg.numeric_tolerance = 1e-9;
cfg.diameter_to_inches = 1;
cfg.length_cost_factor = 1;

cfg.pressure_node_ids = { ...
    '20','30','40','50','55','60','70','75','80','90', ...
    '100','110','115','120','130','140','150','160','170'};
cfg.quality_node_ids = cfg.pressure_node_ids;
cfg.minimum_pressure = 33;
cfg.maximum_pressure = 165;
cfg.pressure_to_head = 2.30666; % ft of water per psi
cfg.pressure_anchor_node_ids = {'65','165'};
cfg.pressure_anchor_target_heads = [215, 215]; % ft
cfg.pressure_anchor_head_tolerance = 0.5; % ft

cfg.cost_coefficient = 230;
cfg.cost_exponent = 0.48;
cfg.quality_duration_hours = 48;
% EPANET requires the quality step not to exceed the 3 h hydraulic step.
% Earlier code requested 48 h, which EPANET silently clamped to 3 h.
cfg.quality_step_hours = 3;
cfg.bulk_reaction_coefficient = -1;
cfg.source_chlorine = 1;
cfg.source_node_ids = {'10'};

% Single-pipe failure stress test. Only the 19 consumer junctions are
% assessed; the true source and pressure-anchor nodes are excluded.
cfg.stress.failed_link_ids = cfg.design_link_ids;
cfg.stress.node_ids = cfg.pressure_node_ids;
cfg.stress.minimum_chlorine = 0.2;

cfg.objectives = {'cost','hydraulic_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
cfg.ga.random_seed = 1993;
cfg.ga.population_size = 100;
% Let MATLAB stop on convergence; retain a high safety ceiling.
cfg.ga.max_generations = 10000;
cfg.ga.max_stall_generations = 150;
cfg.ga.function_tolerance = 1e-6;
% This numerical tolerance is negligible relative to the 0.5-ft anchor band.
cfg.ga.constraint_tolerance = 5e-5;
% A 1.5% interpolation from the original diameters toward the 64-in upper
% bound satisfies both 215-ft pressure-anchor targets and seeds the narrow
% feasible band introduced by the two-sided head constraints.
cfg.ga.feasible_interpolation_to_upper = 0.015;
% A 38-dimensional pattern search is omitted; the production search uses GA.
cfg.ga.use_hybrid_patternsearch = false;
cfg.ga.display = 'final';
cfg.ga.seed_designs = anytown_seed_designs();

cfg.plot.minimum_line_width = 0.45;
cfg.plot.maximum_line_width = 5.5;
cfg.plot.fixed_link_width = 2.0;
cfg.plot.minimum_diameter_tolerance = 0.05;
cfg.plot.node_size = 55;
% Journal figures are cropped into two portrait panels.  These source sizes
% give approximately 10-pt lettering after inclusion at column width.
cfg.plot.diameter_label_font_size = 10;
cfg.plot.axis_padding_fraction = 0.035;
cfg.plot.diameter_label_fraction_by_link = struct();
cfg.plot.diameter_label_offset_by_link = struct();
cfg.plot.diameter_label_link_ids = cfg.design_link_ids;
cfg.plot.link_id_labels_on_original = true;
cfg.plot.link_id_label_font_size = 11;
cfg.plot.pressure_limits = [cfg.minimum_pressure, cfg.maximum_pressure];
cfg.plot.pressure_label = 'Pressure [psi]';
cfg.plot.chlorine_limits = [0, cfg.source_chlorine];
cfg.plot.resolution = 600;
cfg.plot.source_reservoir_node_ids = {'10'};
cfg.plot.pressure_anchor_node_ids = cfg.pressure_anchor_node_ids;
cfg.plot.pump_link_ids = {'82'};
cfg.plot.equipment_marker_size = 95;
cfg.plot.equipment_label_font_size = 10;
cfg.plot.equipment_label_offset = [95, 95];
cfg.plot.pump_symbol_radius = 82;
% Keep the source label inside portrait crops and clear of pump P82.
cfg.plot.equipment_label_offsets.R10 = [-340, -260];

% Reproducible cost--branching-hop search used for Fig. 7.
cfg.multiobjective.random_seed = 202607;
cfg.multiobjective.cost_entropy_random_seed = 202608;
cfg.multiobjective.population_size = 320;
cfg.multiobjective.max_generations = 500;
cfg.multiobjective.max_stall_generations = 150;
cfg.multiobjective.function_tolerance = 1e-5;
cfg.multiobjective.pareto_fraction = 0.90;
cfg.multiobjective.display = 'iter';

% Pipe-ranking study used for Fig. 9. Rankings and all reduced searches are
% evaluated about the same feasible pressure-anchor reference design.
cfg.ranking.perturbation_fraction = 0.10;
cfg.ranking.maximum_rank = 38;
cfg.ranking.k_values = [0:10, 15, 20, 25, 30, 35, 38];
cfg.ranking.random_seed = 202609;
cfg.ranking.population_size = cfg.ga.population_size;
cfg.ranking.max_generations = 100;
cfg.ranking.max_stall_generations = 30;
cfg.ranking.function_tolerance = cfg.ga.function_tolerance;
cfg.ranking.display = 'off';
% New objective-specific cache entries are stored independently. This makes
% the chlorine ranking study resumable without changing the validated
% cost/entropy result files produced before caching was introduced.
cfg.ranking.cache_dir = fullfile(cfg.results_dir, 'ranking_cache');
cfg.ranking.chlorine_figure_basename = ...
    'figure10_anytown_chlorine_ranking_objectives';
end
