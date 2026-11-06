function summary = verify_anytown_anchor_replay_rankings( ...
        paper_root,staci_root,mex_dir)
%VERIFY_ANYTOWN_ANCHOR_REPLAY_RANKINGS Audit saved Figures 9 and 10.
% Re-solve every feasible saved diameter vector in STACI. Check that only
% the selected ranked pipes change, all constraints remain satisfied, each
% archived metric matches the new solve, and the optimized metric is
% monotonic after the first feasible subset. No GA is run.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
cfg=network_config_anchor_replay(network_dir);
saved=load(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
cfg.branch_hop_weighting=saved.result.branch_hop_weighting;
saved=load(fullfile(cfg.results_dir,'pipe_rankings.mat'),'ranking');
ranking=saved.ranking;
st=StaciModel(cfg.inp_file);
cleanup=onCleanup(@()st.release());
ids=string(cfg.design_link_ids(:));
x0=double(st.getLinkProperty(ids,'diameter_m'))'/0.0254;
[link_order,full_original]=wdn.staci_input_link_template( ...
    cfg.inp_file,st,0.0254);
objectives=["cost","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy"];
name=cell(numel(objectives),1);
checked=zeros(numel(objectives),1);
missing_k1=zeros(numel(objectives),1);
max_relative_metric_error=zeros(numel(objectives),1);
max_constraint_violation=zeros(numel(objectives),1);
for oi=1:numel(objectives)
    objective=objectives(oi);
    saved=load(fullfile(cfg.results_dir, ...
        'ranking_'+objective+'_study.mat'),'study');
    study=saved.study;
    saved_full=load(fullfile(cfg.results_dir,objective+'.mat'),'result');
    metric_index=find(strcmp(study.metric_names,objective),1);
    assert(~isempty(metric_index),'Optimized metric absent from study');
    assert(isequal(string(study.criterion_keys), ...
        string(ranking.criterion_keys)), ...
        'Ranking criterion order differs from saved study');
    assert(study.k(1)==0 && study.k(end)==numel(ids), ...
        'Unexpected ranking pipe-count range');
    name{oi}=char(objective);
    for q=1:numel(study.criterion_keys)
        previous=NaN;
        first_feasible=false;
        for j=2:numel(study.k)
            k=study.k(j);
            if ~study.is_feasible(q,j)
                assert(~first_feasible, ...
                    'A nested study lost feasibility at K=%d',k);
                if k==1,missing_k1(oi)=missing_k1(oi)+1;end
                continue
            end
            first_feasible=true;
            x=reshape(study.designs(q,j,:),1,[]);
            selected=ranking.orders(1:k,q);
            fixed=setdiff(1:numel(ids),selected);
            assert(all(abs(x(fixed)-x0(fixed))<1e-8), ...
                'A fixed pipe changed at objective %s, criterion %s, K=%d', ...
                objective,study.criterion_keys{q},k);
            assert(all(x>=cfg.minimum_diameter-1e-8) && ...
                all(x<=cfg.maximum_diameter+1e-8), ...
                'Diameter bound violated at K=%d',k);
            archived=reshape(study.metrics(q,j,:),1,[]);
            objective_value=archived(metric_index);
            if isfinite(previous)
                scale=max(1,abs(previous));
                if objective=="cost"
                    assert(objective_value<=previous+1e-8*scale, ...
                        'Cost reversal at criterion %s, K=%d', ...
                        study.criterion_keys{q},k);
                else
                    assert(objective_value>=previous-1e-8*scale, ...
                        'Maximized-objective reversal at criterion %s, K=%d', ...
                        study.criterion_keys{q},k);
                end
            end
            previous=objective_value;
            [metrics,violation]=wdn.evaluate_staci_design( ...
                st,cfg,x,link_order,full_original);
            if ismember(objective, ...
                    ["chlorine_concentration","chlorine_entropy"])
                violation=max(violation, ...
                    0.2-metrics.minimum_consumer_chlorine_mgL);
            end
            assert(violation<=cfg.ga.constraint_tolerance+1e-5, ...
                'Saved design fails re-evaluated constraints at K=%d',k);
            observed=zeros(1,numel(study.metric_names));
            for mi=1:numel(study.metric_names)
                observed(mi)=metrics.(study.metric_names{mi});
            end
            relative_error=max(abs(observed-archived)./ ...
                max(1,abs(archived)));
            if relative_error>1e-3
                fprintf('Mismatch objective=%s criterion=%s K=%d\n', ...
                    objective,study.criterion_keys{q},k);
                for mi=1:numel(study.metric_names)
                    fprintf('  %s archived=%.12g observed=%.12g\n', ...
                        study.metric_names{mi},archived(mi),observed(mi));
                end
            end
            assert(relative_error<=5e-4, ...
                'Archived metrics differ from fresh solve at K=%d',k);
            checked(oi)=checked(oi)+1;
            max_relative_metric_error(oi)=max( ...
                max_relative_metric_error(oi),relative_error);
            max_constraint_violation(oi)=max( ...
                max_constraint_violation(oi),violation);
            if k==numel(ids)
                assert(max(abs(x(:)- ...
                    saved_full.result.design_diameters(:)))<1e-8, ...
                    'K=N endpoint does not match the final full design');
            end
        end
    end
end
summary=table(name,checked,missing_k1,max_relative_metric_error, ...
    max_constraint_violation,'VariableNames', ...
    {'Objective','FeasibleDesignsChecked','MissingK1Criteria', ...
    'MaxRelativeMetricError','MaxConstraintViolation'});
writetable(summary,fullfile(cfg.results_dir, ...
    'ranking_figures_9_10_audit.csv'));
disp(summary);
end
