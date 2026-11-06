function result = run_tanyimboh_branch_hop_optimization( ...
        paper_root,staci_root,mex_dir)
%RUN_TANYIMBOH_BRANCH_HOP_OPTIMIZATION Full eight-pipe branch-hop GA.
% Uses the same bounds, pressure constraint, STACI model, population and GA
% settings as the five archived TT searches. The frozen topology-only weights
% are written for audit. Candidate hydraulic/quality solves remain in memory.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(network_dir,'-begin');
clear network_config
cfg=network_config(network_dir);
cfg.inp_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
cfg.objectives=[cfg.objectives,{'branch_hop_weighted_entropy'}];
cfg.branch_hop_weighting=tanyimboh_branch_hop_weights(cfg);
w=cfg.branch_hop_weighting;
T=table(string(w.node_ids(:)),w.branch_hops(:),w.weights(:), ...
    w.physical_degree(:),w.demand_exit(:), ...
    'VariableNames',{'NodeID','BranchHops','Weight', ...
    'PhysicalDegree','DemandExit'});
writetable(T,fullfile(cfg.results_dir,'branch_hop_weights.csv'));
output=fullfile(cfg.results_dir,'branch_hop_weighted_entropy.mat');
result=wdn.optimize_staci_single_objective(cfg, ...
    'branch_hop_weighted_entropy',cfg.inp_file,output);
assert(result.max_constraint_violation<=cfg.ga.constraint_tolerance, ...
    'Saved branch-hop diameter vector violates the design constraints');
stop=table("Branch-hop entropy",result.ga_last_generation, ...
    result.output.funccount,result.elapsed_time_seconds,result.exitflag, ...
    result.max_constraint_violation,string(result.output.message), ...
    'VariableNames',{'Objective','Generations','Evaluations', ...
    'WallSeconds','Exitflag','MaxConstraintViolation','StopMessage'});
writetable(stop,fullfile(cfg.results_dir,'branch_hop_ga_stop.csv'));
end
