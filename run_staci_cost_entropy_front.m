function result = run_staci_cost_entropy_front(staci_root, mex_dir)
%RUN_STACI_COST_ENTROPY_FRONT Recompute cost--branching-hop Pareto archive.
root=fileparts(mfilename('fullpath'));
network_dir=fullfile(root,'networks','anytown');
addpath(root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config(network_dir);
cfg.results_dir=fullfile(network_dir,'results_staci');
cfg.figures_dir=fullfile(network_dir,'figures_staci');
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
result=wdn.optimize_staci_cost_entropy_front(cfg,input_file);
save(fullfile(cfg.results_dir,'multiobjective_cost_entropy.mat'), ...
    'result','cfg','-v7');
if ~isfolder(cfg.figures_dir),mkdir(cfg.figures_dir);end
output=fullfile(cfg.figures_dir,'figure7_cost_entropy.png');
wdn.plot_cost_entropy_front(result,cfg,output);
generated=fullfile(root,'manuscript','generated','figures');
if ~isfolder(generated),mkdir(generated);end
copyfile(output,fullfile(generated,'figure7_cost_entropy.png'),'f');
copyfile(replace(output,'.png','.svg'), ...
    fullfile(generated,'figure7_cost_entropy.svg'),'f');
end
