function result=run_anytown_anchor_replay_pareto( ...
        paper_root,staci_root,mex_dir,result_dir_override,make_plot,force_optimization)
%RUN_ANYTOWN_ANCHOR_REPLAY_PARETO Cost versus frozen branch-hop entropy.
if nargin<4,result_dir_override=[];end
if nargin<5,make_plot=true;end
if nargin<6,force_optimization=false;end
result=run_anytown_physical_reservoir_pareto( ...
    paper_root,staci_root,mex_dir,'anchor_replay',result_dir_override, ...
    make_plot,force_optimization);
end
