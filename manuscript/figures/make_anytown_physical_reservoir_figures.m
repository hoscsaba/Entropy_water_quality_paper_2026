function make_anytown_physical_reservoir_figures(nominal_variant)
%MAKE_ANYTOWN_PHYSICAL_RESERVOIR_FIGURES Redraw the six Anytown panels.
% Reads six saved designs; the selected nominal variant determines whether
% the auxiliary reservoirs are physical reservoirs or pressure anchors.
% No GA or outage calculation is launched.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
network_dir=fullfile(root,'networks','anytown');
addpath(network_dir);
if nargin<1,nominal_variant="physical_reservoirs";end
if string(nominal_variant)=="anchor_replay"
    cfg=network_config_anchor_replay(network_dir);
else
    assert(string(nominal_variant)=="physical_reservoirs", ...
        'Unknown nominal variant');
    cfg=network_config_physical_reservoirs(network_dir);
end
wdn.setup_toolkit(cfg);
if ~isfolder(cfg.figures_dir),mkdir(cfg.figures_dir);end
wdn.plot_objective_matrix(cfg,fullfile(cfg.figures_dir,'figure4.png'), ...
    'pressure');
wdn.plot_objective_matrix(cfg,fullfile(cfg.figures_dir,'figure5.png'), ...
    'chlorine','flow_lps');
end
