function result=run_anytown_anchor_replay_pareto(paper_root,staci_root,mex_dir)
%RUN_ANYTOWN_ANCHOR_REPLAY_PARETO Cost versus frozen branch-hop entropy.
result=run_anytown_physical_reservoir_pareto( ...
    paper_root,staci_root,mex_dir,'anchor_replay');
end
