function [normalized,raw]=summarize_anytown_anchor_replay_results( ...
        paper_root,staci_root,mex_dir,result_dir_override)
%SUMMARIZE_ANYTOWN_ANCHOR_REPLAY_RESULTS Cross-evaluate six nominal designs.
if nargin<4,result_dir_override=[];end
[normalized,raw]=summarize_anytown_physical_reservoir_results( ...
    paper_root,staci_root,mex_dir,'anchor_replay',result_dir_override);
end
