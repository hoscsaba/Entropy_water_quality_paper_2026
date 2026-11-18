function refined=refine_anytown_todini_rankings(paper_root,staci_root,mex_dir)
%REFINE_ANYTOWN_TODINI_RANKINGS Audit and improve saved ranked GA incumbents.
% Uses the same 10--120 m, 0.2 mg/L, zero-flow-anchor and diameter limits.
% Only already released diameters vary. Each (ranking,K) has a resumable
% local SQP checkpoint; the original GA study is retained for provenance.
% SQP improves a finite incumbent but does not certify a global optimum.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
network_dir=fullfile(paper_root,'networks','anytown');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_anchor_replay(network_dir);
branch=load(fullfile(cfg.results_dir,'branch_hop_weighted_entropy.mat'),'result');
cfg.branch_hop_weighting=branch.result.branch_hop_weighting;
base=load(fullfile(cfg.results_dir,'ranking_todini_study.mat'),'study');
refined=base.study;
assert(strcmp(refined.objective,'todini'));
r=load(fullfile(cfg.results_dir,'pipe_rankings.mat'),'ranking');
ranking=r.ranking;
assert(isequal(string(refined.criterion_keys),string(ranking.criterion_keys)));
assert(isequal(double(refined.k(:)'),double(cfg.ranking.k_values(:)')));
st=StaciModel(cfg.inp_file);release=onCleanup(@()st.release());
[link_order,original]=wdn.staci_input_link_template(cfg.inp_file,st,0.0254);
original_x=double(refined.original_design(:)');
assert(numel(original_x)==numel(cfg.design_link_ids));
metric_index=find(strcmp(refined.metric_names,'todini'),1);
cache_dir=fullfile(cfg.results_dir,'todini_local_refinement_cache');
if ~isfolder(cache_dir),mkdir(cache_dir);end
refined.local_refinement=struct('method','fmincon SQP, feasible nested incumbents', ...
    'finite_difference_step',0.05,'maximum_iterations',100, ...
    'maximum_evaluations',4000,'source_study', ...
    'ranking_todini_study.mat');
refined.local_refinement_improved=false(size(refined.is_feasible));
refined.local_refinement_seconds=zeros(size(refined.is_feasible));
for q=1:numel(refined.criterion_keys)
    prior=[];prior_k=NaN;
    for j=1:numel(refined.k)
        k=double(refined.k(j));
        if k==0,continue;end
        x_ga=squeeze(base.study.designs(q,j,:))';
        if k==numel(original_x)
            % The unrestricted saved endpoint is a separate GA result.
            if ~isempty(prior)
                assert(refined.metrics(q,j,metric_index)+cfg.ga.function_tolerance >= ...
                    prior.metrics.todini, ...
                    'Restricted Todini design exceeds the saved full endpoint');
            end
            prior=struct('x',x_ga,'metrics',[]);prior_k=k;
            continue;
        end
        selected=ranking.orders(1:k,q)';
        fixed=setdiff(1:numel(original_x),selected);
        assert(all(abs(x_ga(fixed)-original_x(fixed))<1e-8));
        candidates={};sources={};
        if base.study.is_feasible(q,j)
            candidates{end+1}=x_ga;sources{end+1}='GA'; %#ok<AGROW>
        end
        if ~isempty(prior)
            candidates{end+1}=prior.x;sources{end+1}=sprintf('nested K=%d',prior_k); %#ok<AGROW>
        end
        if isempty(candidates),continue;end
        best=-inf;start_x=[];start_source='';
        for z=1:numel(candidates)
            xx=candidates{z};
            [mm,vv]=wdn.evaluate_staci_design(st,cfg,xx,link_order,original);
            if vv<=cfg.ga.constraint_tolerance && mm.todini>best
                best=mm.todini;start_x=xx;start_source=sources{z};
            end
        end
        if isempty(start_x),continue;end
        checkpoint=fullfile(cache_dir,sprintf('%s_k_%03d.mat', ...
            refined.criterion_keys{q},k));
        if isfile(checkpoint)
            saved=load(checkpoint,'audit');audit=saved.audit;
            assert(isequal(audit.selected(:),selected(:)));
            if ~isfield(audit.metrics,'branch_hop_weighted_entropy')
                [audit.metrics,audit.violation]=wdn.evaluate_staci_design( ...
                    st,cfg,audit.chosen_x,link_order,original);
                save(checkpoint,'audit','-v7');
            end
        else
            started=tic;
            [trial_x,exitflag,evaluations]=local_sqp(start_x,selected);
            [trial_metrics,trial_violation]=wdn.evaluate_staci_design( ...
                st,cfg,trial_x,link_order,original);
            if trial_violation<=cfg.ga.constraint_tolerance && ...
                    trial_metrics.todini>best+1e-8
                chosen_x=trial_x;chosen_metrics=trial_metrics;
                chosen_violation=trial_violation;improved=true;
            else
                chosen_x=start_x;
                [chosen_metrics,chosen_violation]=wdn.evaluate_staci_design( ...
                    st,cfg,chosen_x,link_order,original);
                improved=false;
            end
            audit=struct('selected',selected,'start_x',start_x, ...
                'start_source',start_source,'chosen_x',chosen_x, ...
                'metrics',chosen_metrics,'violation',chosen_violation, ...
                'improved',improved,'exitflag',exitflag, ...
                'evaluations',evaluations,'elapsed_seconds',toc(started));
            save(checkpoint,'audit','-v7');
        end
        % Resident-model SQP evaluations can differ slightly from a fresh
        % hydraulic solve at active constraints. Select the published point
        % from fresh-model checks of the SQP, GA and nested incumbent.
        final_x=[];final_metrics=[];final_violation=inf;
        final_score=-inf;
        final_candidates={audit.chosen_x};
        if base.study.is_feasible(q,j)
            final_candidates{end+1}=x_ga; %#ok<AGROW>
        end
        if ~isempty(prior)
            final_candidates{end+1}=prior.x; %#ok<AGROW>
        end
        for z=1:numel(final_candidates)
            xx=final_candidates{z};
            [mm,vv]=evaluate_fresh(xx);
            if vv<=cfg.ga.constraint_tolerance && mm.todini>final_score
                final_x=xx;final_metrics=mm;
                final_violation=vv;final_score=mm.todini;
            end
        end
        assert(~isempty(final_x),'No freshly feasible Todini incumbent');
        audit.chosen_x=final_x;
        audit.metrics=final_metrics;
        audit.violation=final_violation;
        audit.improved=final_score>base.study.metrics(q,j,metric_index)+1e-8;
        save(checkpoint,'audit','-v7');
        assert(all(abs(audit.chosen_x(fixed)-original_x(fixed))<1e-8));
        refined.designs(q,j,:)=audit.chosen_x;
        refined.max_constraint_violations(q,j)=audit.violation;
        refined.is_feasible(q,j)=audit.violation<=cfg.ga.constraint_tolerance;
        for m=1:numel(refined.metric_names)
            refined.metrics(q,j,m)=audit.metrics.(refined.metric_names{m});
        end
        refined.local_refinement_improved(q,j)=audit.improved;
        refined.local_refinement_seconds(q,j)=audit.elapsed_seconds;
        prior=struct('x',audit.chosen_x,'metrics',audit.metrics);prior_k=k;
        fprintf('%s K=%d: Todini %.9f -> %.9f, violation %.3g (%s)\n', ...
            refined.criterion_keys{q},k,best,audit.metrics.todini, ...
            audit.violation,audit.start_source);
    end
end
output=fullfile(cfg.results_dir,'ranking_todini_refined_study.mat');
save(output,'refined','-v7');
wdn.write_ranking_study_csv(cfg,refined, ...
    'ranking_todini_refined_study.csv');
left=load(fullfile(cfg.results_dir, ...
    'ranking_hydraulic_entropy_study.mat'),'study');
wdn.plot_ranking_pair_matrix(cfg,left.study,refined, ...
    'anytown_hydraulic_todini_rankings');
clear release st

    function [mm,vv]=evaluate_fresh(xx)
        fresh=StaciModel(cfg.inp_file);
        fresh_release=onCleanup(@()fresh.release());
        [mm,vv]=wdn.evaluate_staci_design( ...
            fresh,cfg,xx,link_order,original);
        clear fresh_release fresh
    end

    function [trial_x,exitflag,evaluations]=local_sqp(start_x,selected)
        k_local=numel(selected);last_y=[];last_f=[];last_c=[];evaluations=0;
        y0=double(start_x(selected(:)))';y0=y0(:);
        options=optimoptions('fmincon','Algorithm','sqp','Display','off', ...
            'MaxIterations',100,'MaxFunctionEvaluations',4000, ...
            'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-7, ...
            'StepTolerance',1e-9,'FiniteDifferenceType','forward', ...
            'FiniteDifferenceStepSize',0.05);
        [yy,~,exitflag]=fmincon(@fitness,y0,[],[],[],[], ...
            cfg.minimum_diameter*ones(k_local,1), ...
            cfg.maximum_diameter*ones(k_local,1),@constraints,options);
        trial_x=start_x;trial_x(selected)=yy;
        function f=fitness(y)
            calculate(y);f=last_f;
        end
        function [c,ceq]=constraints(y)
            calculate(y);c=last_c;ceq=[];
        end
        function calculate(y)
            y=double(y(:));if isequal(y,last_y),return;end
            xx=start_x;xx(selected)=y;
            try
                st.setLinkProperty(string(cfg.design_link_ids(:)), ...
                    'diameter_m',xx(:)*0.0254);
                status=st.solveHydraulics();assert(status.converged);
                nodes=st.nodeResults();ids=string(nodes.id(:));
                pressure=double(nodes.pressure_head_m(:));
                [found,pi]=ismember(string(cfg.pressure_node_ids(:)),ids);
                assert(all(found));
                lower_pressure=cfg.minimum_pressure+ ...
                    cfg.ga.pressure_numerical_guard_m;
                upper_pressure=cfg.maximum_pressure- ...
                    cfg.ga.pressure_numerical_guard_m;
                c=[lower_pressure-pressure(pi);pressure(pi)-upper_pressure];
                [found,ai]=ismember(string(cfg.pressure_anchor_node_ids(:)),ids);
                assert(all(found));
                anchor=double(nodes.total_head_m(ai))/0.3048;
                c=[c;abs(anchor(:)-cfg.pressure_anchor_target_heads(:))- ...
                    (cfg.pressure_anchor_head_tolerance- ...
                    cfg.ga.anchor_numerical_guard_ft)];
                quality=st.solveSteadyQuality('chemical');
                cl=wdn.consumer_chlorine_constraint(nodes,quality);
                c=[c;cl(:)];
                f=-wdn.staci_todini_index(st,cfg);
            catch
                f=1e6;
                c=1e6*ones(2*numel(cfg.pressure_node_ids)+ ...
                    numel(cfg.pressure_anchor_node_ids)+ ...
                    numel(cfg.quality_node_ids),1);
            end
            last_y=y;last_f=f;last_c=c;evaluations=evaluations+1;
        end
    end
end
