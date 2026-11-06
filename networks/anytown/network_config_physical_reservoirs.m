function cfg = network_config_physical_reservoirs(network_dir)
%NETWORK_CONFIG_PHYSICAL_RESERVOIRS Anytown with both 215-ft basins connected.
% The nominal optimization and outage replay share the same physical source
% interpretation. Results are isolated from the earlier pressure-anchor run.
if nargin==0,network_dir=fileparts(mfilename('fullpath'));end
cfg=network_config(network_dir);
nominal=fullfile(network_dir,'input','network_staci_fixed_load.inp');
physical=fullfile(network_dir,'input','network_physical_reservoirs.inp');
wdn.write_staci_anytown_outage_input(cfg,nominal,physical);
% Three hydraulic sources can make extreme GA trial diameters harder for
% Newton iteration. Raise only the numerical iteration budget; all heads,
% demands, reactions, and physical link data remain identical.
content=fileread(physical);
updated=regexprep(content,'(?m)^[ \t]*TRIALS[ \t]+40[ \t]*$', ...
    ' TRIALS 200');
assert(~strcmp(content,updated),'Expected a 40-trial nominal INP');
fid=fopen(physical,'w');
assert(fid>0,'Cannot write physical-reservoir INP');
close_file=onCleanup(@()fclose(fid));
fwrite(fid,updated,'char');
clear close_file
cfg.inp_file=physical;
cfg.results_dir=fullfile(network_dir,'results_staci_physical_reservoirs');
cfg.figures_dir=fullfile(network_dir,'figures_staci_physical_reservoirs');
cfg.runtime_dir=fullfile(network_dir,'runtime_physical_reservoirs');
cfg.ranking.cache_dir=fullfile(cfg.results_dir,'ranking_cache');
cfg.source_node_ids={'10','65','165'};
cfg.pressure_anchor_node_ids={};
cfg.pressure_anchor_target_heads=[];
cfg.plot.source_reservoir_node_ids={'10','65','165'};
cfg.plot.pressure_anchor_node_ids={};
cfg.ga=rmfield(cfg.ga,'feasible_interpolation_to_upper');
end
