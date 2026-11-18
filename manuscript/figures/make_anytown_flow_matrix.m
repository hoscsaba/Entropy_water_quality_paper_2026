function make_anytown_flow_matrix(root)
%MAKE_ANYTOWN_FLOW_MATRIX Replot the six saved Anytown designs in 3-by-2 form.
% Pipe labels are absolute steady flows in L/s and node colors are
% stationary chlorine concentrations from saved STACI result MAT files.
% No optimization or hydraulic/quality solve is performed here.
if nargin<1 || isempty(root)
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
assert(isfolder(fullfile(root,'networks','anytown')), ...
    'Run from the paper repository or add its figure scripts to the path');
addpath(root);
network_dir=fullfile(root,'networks','anytown');
addpath(network_dir);
cfg=network_config_anchor_replay(network_dir);
wdn.setup_toolkit(cfg);
if ~isfolder(cfg.figures_dir), mkdir(cfg.figures_dir); end
cfg.plot.matrix_objectives={'cost','hydraulic_entropy', ...
    'branch_hop_weighted_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
cfg.plot.matrix_titles={'Cost','Flow-weighted entropy', ...
    'Branch-hop entropy','Chlorine concentration', ...
    'Chlorine entropy','Todini index'};
layout_options=struct('layout_shape',[3,2]);
out=fullfile(cfg.figures_dir,'anytown_objectives_flow_3x2.png');
wdn.plot_objective_matrix(cfg,out,'chlorine','flow_lps',layout_options);
generated=fullfile(root,'manuscript','generated','figures');
if ~isfolder(generated),mkdir(generated);end
copyfile(out,fullfile(generated,'anytown_objectives_flow_3x2.png'),'f');
copyfile(fullfile(cfg.figures_dir,'anytown_objectives_flow_3x2.svg'), ...
    fullfile(generated,'anytown_objectives_flow_3x2.svg'),'f');
end
