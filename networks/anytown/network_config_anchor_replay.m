function cfg = network_config_anchor_replay(network_dir)
%NETWORK_CONFIG_ANCHOR_REPLAY Nominal zero-flow anchors, physical outage basins.
% R65/R165 are zero-demand terminal junctions in the nominal INP. Their
% target total heads (215 +/- 0.5 ft) are nonlinear design constraints;
% R10/pump 82 must supply all nominal demand. Failure replay restores the
% fixed-head reservoirs. Keep these results separate from both earlier runs.
if nargin<1, network_dir=fileparts(mfilename('fullpath')); end
cfg=network_config(network_dir);
% EPANET 2.2 reports 1 psi as 2.30787 ft of water in this INP. The
% archived 2.30666 factor makes an STACI 33-psi limit about 0.017 psi too
% permissive on independent EPANET replay, so this variant uses its factor.
cfg.pressure_to_head=2.30787;
source=fullfile(network_dir,'input','network_staci_fixed_load.inp');
cfg.inp_file=fullfile(network_dir,'input','network_anchor_replay.inp');
content=fileread(source);
updated=regexprep(content,'(?m)^[ \t]*TRIALS[ \t]+40[ \t]*$', ...
    ' TRIALS 200');
assert(~strcmp(content,updated),'Expected a 40-trial nominal source INP');
fid=fopen(cfg.inp_file,'w');
assert(fid>0,'Cannot write anchor-replay input');
release=onCleanup(@()fclose(fid));
fwrite(fid,updated,'char');
clear release
cfg.results_dir=fullfile(network_dir,'results_staci_anchor_replay');
cfg.figures_dir=fullfile(network_dir,'figures_staci_anchor_replay');
cfg.runtime_dir=fullfile(network_dir,'runtime_anchor_replay');
cfg.ranking.cache_dir=fullfile(cfg.results_dir,'ranking_cache');
cfg.objectives=[cfg.objectives,{'branch_hop_weighted_entropy'}];
cfg.ga.maximum_wall_seconds=7200;
% Small interior margins keep final cross-engine replay away from active
% constraint boundaries and absorb hydraulic-solver roundoff.
cfg.ga.anchor_numerical_guard_ft=0.02;
cfg.ga.pressure_numerical_guard_psi=0.03;
cfg.plot.source_reservoir_node_ids={'10'};
cfg.plot.pressure_anchor_node_ids={'65','165'};
assert(isequal(string(cfg.source_node_ids),"10") && ...
    isequal(string(cfg.pressure_anchor_node_ids),["65","165"]), ...
    'Anytown nominal source model is not pump-only with two anchors');
end
