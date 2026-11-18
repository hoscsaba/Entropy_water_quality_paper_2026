function candidate_file=refine_balerma_r38_branch_from_pareto( ...
        paper_root,staci_root,mex_dir,maximum_wall_seconds)
%REFINE_BALERMA_R38_BRANCH_FROM_PARETO Improve the full branch-hop search.
% A feasible 90-pipe Pareto endpoint can outperform a finite independent
% 454-pipe GA. Use that candidate, several nearby Pareto points, and the
% previous full result as seeds for one further full-network GA. The new
% result is saved separately for explicit adjudication and EPANET audit.
if nargin<4 || isempty(maximum_wall_seconds),maximum_wall_seconds=1800;end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
saved=load(fullfile(cfg.results_dir, ...
    'pareto_cost_branch_hop_top90.mat'),'result');
archive=saved.result;
assert(strcmp(archive.constraint_set_id,cfg.constraint_set_id) && ...
    strcmp(archive.branch_hop_weighting_version, ...
    cfg.branch_hop_weighting.version) && ...
    archive.optimized_pipe_count==90 && ...
    all(archive.max_constraint_violation<=cfg.ga.constraint_tolerance), ...
    'Pareto archive is incompatible or infeasible');
[~,order]=sort(double(archive.branch_hop_entropy(:)),'descend');
previous=load(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
seeds=double(archive.designs(order(1:min(18,numel(order))),:));
seeds=[seeds;double(previous.result.design_diameters(:)')];
cfg.ga.seed_designs.branch_hop_weighted_entropy=seeds(1,:);
cfg.ga.additional_seed_designs=seeds(2:end,:);
cfg.ga.maximum_wall_seconds=maximum_wall_seconds;
candidate_dir=fullfile(cfg.results_dir,'refined_ga');
if ~isfolder(candidate_dir),mkdir(candidate_dir);end
candidate_file=fullfile(candidate_dir, ...
    'branch_hop_from_pareto.mat');
result=wdn.optimize_staci_single_objective(cfg, ...
    'branch_hop_weighted_entropy',cfg.inp_file,candidate_file);
result.nominal_pressure_anchor_node_ids={'38'};
result.nominal_physical_reservoir_node_ids={'43','44','88'};
result.physical_replay_reservoir_node_ids={'38','43','44','88'};
result.seed_source='best feasible top-90 Pareto design';
save(candidate_file,'result','-v7');
fprintf('Pareto-seeded full branch-hop: %.9f nat, generation %d, %.1f s, violation %.4g\n', ...
    result.metrics.branch_hop_weighted_entropy, ...
    result.ga_last_generation,result.elapsed_time_seconds, ...
    result.max_constraint_violation);
end
