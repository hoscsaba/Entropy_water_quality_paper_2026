function refine_anytown_anchor_replay_endpoints(paper_root,staci_root,mex_dir)
%REFINE_ANYTOWN_ANCHOR_REPLAY_ENDPOINTS Continue two full-network searches.
% A feasible 35-pipe ranked design can outperform an earlier 38-pipe GA
% incumbent. Feed the best ranked vectors back to the unrestricted GA,
% verify the result on a fresh STACI model, and retain the old endpoint.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
cfg=network_config_anchor_replay(network_dir);
cfg.branch_hop_weighting=anytown_anchor_replay_weights(cfg);
objectives=["branch_hop_weighted_entropy","chlorine_entropy"];
for j=1:numel(objectives)
    objective=objectives(j);
    file=fullfile(cfg.results_dir,objective+'.mat');
    loaded=load(file,'result');old=loaded.result;
    loaded=load(fullfile(cfg.results_dir, ...
        'ranking_'+objective+'_study.mat'),'study');
    study=loaded.study;
    metric=find(strcmp(string(study.metric_names),objective),1);
    assert(isscalar(metric),'Ranked objective metric is missing');
    values=study.metrics(:,:,metric);
    values(~study.is_feasible | study.k(:)'==38)=NaN;
    [~,order]=sort(values(:),'descend','MissingPlacement','last');
    order=order(isfinite(values(order)));
    assert(~isempty(order),'No feasible ranked seed');
    n=min(20,numel(order));
    seeds=zeros(n+1,numel(cfg.design_link_ids));
    for k=1:n
        [row,col]=ind2sub(size(values),order(k));
        seeds(k,:)=reshape(study.designs(row,col,:),1,[]);
    end
    seeds(end,:)=double(old.design_diameters(:)');
    cfg.ga.additional_seed_designs=seeds;
    cfg.ga.random_seed=20261106+j;
    fprintf('%s: old %.9f, best ranked seed %.9f\n', ...
        objective,old.metrics.(objective),values(order(1)));
    result=wdn.optimize_staci_single_objective(cfg,char(objective), ...
        cfg.inp_file,'');
    fresh=StaciModel(cfg.inp_file);
    release=onCleanup(@()fresh.release());
    [link_order,original]=wdn.staci_input_link_template( ...
        cfg.inp_file,fresh,0.0254);
    [m,violation]=wdn.evaluate_staci_design(fresh,cfg, ...
        result.design_diameters,link_order,original);
    assert(violation<=cfg.ga.constraint_tolerance, ...
        'Refined endpoint fails fresh-model constraints');
    ids=string(m.link_ids(:));flows=double(m.flows_m3s(:));
    assert(all(abs(flows(ismember(ids,["78","80"])))<1e-9), ...
        'Refined endpoint draws water from a nominal anchor');
    assert(abs(flows(ids=="82")-0.282644079872)<1e-6, ...
        'Refined endpoint pump does not cover nominal demand');
    if objective=="chlorine_entropy"
        assert(m.minimum_consumer_chlorine_mgL>=0.2-1e-6, ...
            'Refined chlorine endpoint violates residual floor');
    end
    result.max_constraint_violation=violation;
    assert(m.(objective)>old.metrics.(objective)+1e-7, ...
        'Refinement did not improve the saved endpoint');
    archive=fullfile(cfg.results_dir,objective+ ...
        '_pre_rank_refinement.mat');
    save(archive,'old','-v7');
    save(file,'result','-v7');
    fprintf('%s: refined objective %.9f, %d generations\n', ...
        objective,m.(objective),result.ga_last_generation);
    clear release fresh
end
end
