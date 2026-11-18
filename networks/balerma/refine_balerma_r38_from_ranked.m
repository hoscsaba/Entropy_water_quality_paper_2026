function candidate_file=refine_balerma_r38_from_ranked( ...
        paper_root,staci_root,mex_dir,objective,maximum_wall_seconds)
%REFINE_BALERMA_R38_FROM_RANKED Retry a full GA from feasible K=90 designs.
% A 90-pipe search can find a stronger feasible incumbent than a finite
% 454-pipe GA. Re-evaluate all K=90 ranking candidates against the current
% nominal model, then use the best and the previous full design as seeds.
% The candidate is saved separately; adoption requires an explicit audit.
if nargin<5 || isempty(maximum_wall_seconds),maximum_wall_seconds=1800;end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
objective=string(objective);
assert(ismember(objective,string(cfg.objectives)));
ranking=load(fullfile(cfg.results_dir,'pipe_rankings.mat'),'ranking');
keys=ranking.ranking.criterion_keys;
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[links,original]=wdn.staci_input_link_template(cfg.inp_file,st,0.001);
seeds=[];scores=[];
for q=1:numel(keys)
    file=fullfile(cfg.results_dir,'ranking_cache',char(objective), ...
        keys{q},'k_090.mat');
    if ~isfile(file),continue;end
    saved=load(file,'entry');
    x=double(saved.entry.design_diameters(:)');
    [m,v]=wdn.evaluate_staci_design(st,cfg,x,links,original);
    if v>cfg.ga.constraint_tolerance,continue;end
    seeds(end+1,:)=x; %#ok<AGROW>
    scores(end+1,1)=double(m.(char(objective))); %#ok<AGROW>
end
assert(~isempty(seeds),'No feasible K=90 ranking candidates');
if objective=="cost",[~,order]=sort(scores,'ascend');
else,[~,order]=sort(scores,'descend');end
seeds=seeds(order,:);
previous=load(fullfile(cfg.results_dir,objective+".mat"),'result');
seeds=[seeds;double(previous.result.design_diameters(:)')];
if objective=="branch_hop_weighted_entropy"
    archive=load(fullfile(cfg.results_dir, ...
        'pareto_cost_branch_hop_top90.mat'),'result');
    [~,porder]=sort(archive.result.branch_hop_entropy,'descend');
    seeds=[seeds;double(archive.result.designs( ...
        porder(1:min(5,numel(porder))),:))];
end
cfg.ga.seed_designs.(char(objective))=seeds(1,:);
cfg.ga.additional_seed_designs=seeds(2:end,:);
cfg.ga.maximum_wall_seconds=maximum_wall_seconds;
clear release st
candidate_dir=fullfile(cfg.results_dir,'refined_ga');
if ~isfolder(candidate_dir),mkdir(candidate_dir);end
candidate_file=fullfile(candidate_dir,objective+"_from_ranked.mat");
result=wdn.optimize_staci_single_objective( ...
    cfg,char(objective),cfg.inp_file,candidate_file);
result.nominal_pressure_anchor_node_ids={'38'};
result.nominal_physical_reservoir_node_ids={'43','44','88'};
result.physical_replay_reservoir_node_ids={'38','43','44','88'};
result.seed_source='five feasible K=90 ranked-subset results';
save(candidate_file,'result','-v7');
fprintf('RANK-SEEDED %s: %.9g, generation %d, %.1f s, violation %.4g\n', ...
    objective,result.metrics.(char(objective)), ...
    result.ga_last_generation,result.elapsed_time_seconds, ...
    result.max_constraint_violation);
end
