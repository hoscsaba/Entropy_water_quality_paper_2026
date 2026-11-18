function run_anytown_anchor_replay_rankings( ...
        paper_root,staci_root,mex_dir,objectives,result_dir_override,make_plots)
%RUN_ANYTOWN_ANCHOR_REPLAY_RANKINGS Cached nominal pipe-subset searches.
if nargin<4,objectives=[];end
if nargin<5,result_dir_override=[];end
if nargin<6,make_plots=true;end
run_anytown_physical_reservoir_rankings( ...
    paper_root,staci_root,mex_dir,objectives,'anchor_replay', ...
    result_dir_override,make_plots);
end
