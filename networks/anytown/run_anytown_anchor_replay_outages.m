function [pda_pooled,pda_by_availability,pda_all_cases] = run_anytown_anchor_replay_outages( ...
        paper_root,staci_root,mex_dir,result_dir_override)
%RUN_ANYTOWN_ANCHOR_REPLAY_OUTAGES PDA-only replay of nominal anchor designs.
% The two tanks are restored at 215 ft, with both/only R65/only R165
% availability states. Every physical pipe is closed in turn.
if nargin<4,result_dir_override=[];end
[pda_pooled,pda_by_availability,pda_all_cases]= ...
    run_anytown_physical_reservoir_outages( ...
    paper_root,staci_root,mex_dir,'anchor_replay',result_dir_override);
end
