function [dda,pda]=run_anytown_anchor_replay_outages(paper_root,staci_root,mex_dir)
%RUN_ANYTOWN_ANCHOR_REPLAY_OUTAGES Replay nominal anchor designs with basins.
% Saved diameters stay fixed. Both basins, R65 only, and R165 only are
% independently paired with closure of every physical design pipe.
[dda,pda]=run_anytown_physical_reservoir_outages( ...
    paper_root,staci_root,mex_dir,'anchor_replay');
end
