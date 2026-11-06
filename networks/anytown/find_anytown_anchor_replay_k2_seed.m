function seed = find_anytown_anchor_replay_k2_seed( ...
        paper_root,staci_root,mex_dir)
%FIND_ANYTOWN_ANCHOR_REPLAY_K2_SEED Repair a narrow two-pipe feasible set.
% Four rankings release the same two physical pipes (2 and 4) at K=2.
% A short GA can miss their narrow pressure-anchor feasible region. This
% bounded pattern search minimizes the maximum design constraint violation
% and saves a feasible full diameter vector for subsequent objective GAs.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
cfg=network_config_anchor_replay(network_dir);
saved=load(fullfile(cfg.results_dir,'pipe_rankings.mat'),'ranking');
ranking=saved.ranking;
q=find(strcmp(ranking.criterion_keys,'flow_rate'),1);
selected=ranking.orders(1:2,q)';
assert(isequal(sort(string(cfg.design_link_ids(selected))),["2","4"]), ...
    'The documented two-pipe ranking subset has changed');
st=StaciModel(cfg.inp_file);
cleanup=onCleanup(@()st.release());
ids=string(cfg.design_link_ids(:));
x0=double(st.getLinkProperty(ids,'diameter_m'))'/0.0254;
[link_order,full_original]=wdn.staci_input_link_template( ...
    cfg.inp_file,st,0.0254);
cache=load(fullfile(cfg.results_dir,'ranking_cache', ...
    'branch_hop_weighted_entropy','flow_rate','k_002.mat'),'entry');
y0=cache.entry.design_diameters(selected);
opts=optimoptions('patternsearch','Display','off', ...
    'MaxIterations',250,'MaxFunctionEvaluations',1500, ...
    'MeshTolerance',1e-7,'FunctionTolerance',1e-9, ...
    'UseCompletePoll',true);
[y,~,exitflag,output]=patternsearch(@constraint_violation,y0, ...
    [],[],[],[],cfg.minimum_diameter*ones(1,2), ...
    cfg.maximum_diameter*ones(1,2),[],opts);
x=x0;x(selected)=y(:)';
[metrics,violation]=wdn.evaluate_staci_design( ...
    st,cfg,x,link_order,full_original);
chlorine_violation=max(0,0.2-metrics.minimum_consumer_chlorine_mgL);
assert(max(violation,chlorine_violation)<=cfg.ga.constraint_tolerance, ...
    'No feasible two-pipe seed found; minimum violation %.8g', ...
    max(violation,chlorine_violation));
seed.design_diameters=x;
seed.selected_link_ids=string(cfg.design_link_ids(selected));
seed.max_constraint_violation=max(violation,chlorine_violation);
seed.minimum_consumer_chlorine_mgL= ...
    metrics.minimum_consumer_chlorine_mgL;
seed.search_exitflag=exitflag;
seed.search_evaluations=output.funccount;
seed.method='bounded pattern search for feasibility; objective GAs follow';
save(fullfile(cfg.results_dir,'k2_feasibility_seed.mat'),'seed','-v7');
fprintf('Anytown K=2 feasible seed: pipes %s, d=%s in, violation %.8g, minimum Cl %.5g mg/L\n', ...
    strjoin(cellstr(seed.selected_link_ids),','),mat2str(y,8), ...
    seed.max_constraint_violation,seed.minimum_consumer_chlorine_mgL);

    function v=constraint_violation(candidate)
        trial=x0;trial(selected)=candidate(:)';
        try
            [m,hydraulic_violation]=wdn.evaluate_staci_design( ...
                st,cfg,trial,link_order,full_original);
            v=max(hydraulic_violation, ...
                0.2-m.minimum_consumer_chlorine_mgL);
        catch
            v=1e6;
        end
    end
end
