function run_anytown_anchor_replay_rankings( ...
        paper_root,staci_root,mex_dir,objectives)
%RUN_ANYTOWN_ANCHOR_REPLAY_RANKINGS Cached nominal pipe-subset searches.
if nargin<4,objectives=[];end
run_anytown_physical_reservoir_rankings( ...
    paper_root,staci_root,mex_dir,objectives,'anchor_replay');
end
