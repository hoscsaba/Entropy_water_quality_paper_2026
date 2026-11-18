function result=refine_uniform_endpoint_from_rank_cache( ...
        paper_root,staci_root,mex_dir,objective,result_dir)
%REFINE_UNIFORM_ENDPOINT_FROM_RANK_CACHE Continue a full Anytown search.
% A feasible K<38 ranked design can beat the independently stopped
% full-network GA. Promote it only as a warm start, rerun all 38 variables
% under the same pressure and chlorine constraints, and then rerun the
% ranked study so its K=38 point equals this reviewed full-network result.
objective=string(objective);
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
nd=fullfile(paper_root,'networks','anytown');
addpath(nd);
cfg=network_config_anchor_replay(nd);
cfg.branch_hop_weighting=anytown_anchor_replay_weights(cfg);
cfg.results_dir=char(result_dir);
cfg.ga.maximum_wall_seconds=7200;
cfg.ga.display='final';
target=fullfile(cfg.results_dir,objective+'.mat');
loaded=load(target,'result');old=loaded.result;
assert(isfield(old,'constraint_set_id') && ...
    strcmp(old.constraint_set_id,'pressure_10_120m_chlorine_mass_split_v2'), ...
    'The saved endpoint has a different constraint set');
files=dir(fullfile(cfg.results_dir,'ranking_cache',char(objective), ...
    '*','k_*.mat'));
n=numel(cfg.design_link_ids);
seeds=zeros(0,n);scores=zeros(0,1);
for k=1:numel(files)
    saved=load(fullfile(files(k).folder,files(k).name),'entry');
    e=saved.entry;
    if e.k>=n || ~e.is_feasible || ...
            ~isfield(e.metrics,char(objective))
        continue
    end
    seeds(end+1,:)=double(e.design_diameters(:)'); %#ok<AGROW>
    scores(end+1,1)=double(e.metrics.(char(objective))); %#ok<AGROW>
end
assert(~isempty(scores),'No feasible ranked warm starts found');
if objective=="cost"
    [~,order]=sort(scores,'ascend');
    better=scores(order(1))<old.metrics.cost-1e-7;
else
    [~,order]=sort(scores,'descend');
    better=scores(order(1))>old.metrics.(char(objective))+1e-7;
end
if ~better
    fprintf('%s: full endpoint already beats every ranked cache entry\n', ...
        objective);
    result=old;
    return
end
seeds=[double(old.design_diameters(:)'); ...
    seeds(order(1:min(20,numel(order))),:)];
cfg.ga.additional_seed_designs=unique(seeds,'rows','stable');
cfg.ga.random_seed=20261106+sum(double(char(objective)));
archive=fullfile(cfg.results_dir,objective+'_pre_rank_refinement.mat');
if ~isfile(archive),save(archive,'old','-v7');end
fprintf('%s: full %.9g, best ranked %.9g; rerunning all %d pipes\n', ...
    objective,old.metrics.(char(objective)),scores(order(1)),n);
result=wdn.optimize_staci_single_objective(cfg,char(objective), ...
    cfg.inp_file,target);
if objective=="cost"
    assert(result.metrics.cost<=scores(order(1))+1e-7, ...
        'Full GA did not retain the feasible ranked cost seed');
else
    assert(result.metrics.(char(objective))>=scores(order(1))-1e-7, ...
        'Full GA did not retain the feasible ranked entropy seed');
end
result.refined_from_rank_cache=true;
save(target,'result','-v7');
end
