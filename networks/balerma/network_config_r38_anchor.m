function cfg=network_config_r38_anchor(network_dir)
%NETWORK_CONFIG_R38_ANCHOR Nominal R38 anchor, physical R43/R44/R88.
% R38 is a zero-demand junction in the nominal INP. Its original 117 m
% total head is enforced to 0.5 ft tolerance as an optimization constraint.
% Failure replay uses the untouched physical input and all four reservoirs.
if nargin<1,network_dir=fileparts(mfilename('fullpath'));end
cfg=network_config(network_dir);
physical=fullfile(network_dir,'input','network_staci_fixed_load.inp');
nominal=fullfile(network_dir,'input','network_r38_anchor_fixed_load.inp');
write_balerma_r38_anchor_input(physical,nominal);
cfg.inp_file=nominal;
cfg.results_dir=fullfile(network_dir, ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
cfg.runtime_dir=fullfile(cfg.results_dir,'runtime');
cfg.ranking.cache_dir=fullfile(cfg.results_dir,'ranking_cache');
cfg.ranking.k_values=[0,5,20,45,70,90];
cfg.ranking.max_rank_display=90;
cfg.ranking.maximum_wall_seconds=14400;
cfg.ranking.figure_basename='balerma_r38_cost_branch_rankings';
cfg.ranking.chlorine_figure_basename='balerma_r38_chlorine_rankings';
seed_file=fullfile(cfg.results_dir,'feasible_seed.mat');
if isfile(seed_file)
    saved_seed=load(seed_file,'x');
    cfg.ranking.reference_design=double(saved_seed.x(:)');
end
cfg.constraint_set_id='balerma_r38_zero_flow_117m_r44_physical_0p1_64in_v1';
cfg.source_node_ids={'43','44','88'};
cfg.pressure_anchor_node_ids={'38'};
% The existing shared optimizer represents anchor heads and tolerance in
% feet, even for SI networks; convert the original 117 m without rounding.
cfg.pressure_anchor_target_heads=117/0.3048;
cfg.pressure_anchor_head_tolerance=0.5;
cfg.ga.anchor_numerical_guard_ft=0.02;
cfg.ga.pressure_numerical_guard_m=0.02;
% Leave 0.001 mg/L inside the physical 0.2 mg/L chlorine floor so that
% the independently checked EPANET concentration does not round below it.
cfg.ga.chlorine_numerical_guard_mgL=0.001;
cfg.ga.maximum_wall_seconds=7200;
cfg.ga.display='final';
cfg.objectives={'cost','hydraulic_entropy', ...
    'branch_hop_weighted_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
% Potential emergency supply entries determine topology-only weights even
% though R38 is not an operating source in the intact design calculation.
weight_cfg=cfg;
weight_cfg.inp_file=physical;
weight_cfg.source_node_ids={'38','43','44','88'};
cfg.branch_hop_weighting=balerma_connected_branch_weights(weight_cfg);
cfg.branch_hop_weighting.version= ...
    'balerma_r38_anchor_four_potential_supply_roots_v1';
cfg.branch_hop_weighting.distance_definition= ...
    'undirected topology, four potential reservoir entries as zero-hop roots';
protected=["5","338","194","223","188","51"];
eligible=string(cfg.design_link_ids(:));
eligible=eligible(~ismember(eligible,protected));
assert(numel(eligible)==448 && numel(unique(eligible))==448, ...
    'Protected reservoir connector set changed');
cfg.stress.failed_link_ids=cellstr(eligible);
cfg.stress.protected_link_ids=cellstr(protected);
cfg.stress.allow_pda_tolerance_fallback=true;
end
