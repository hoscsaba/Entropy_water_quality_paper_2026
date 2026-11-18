function result = run_balerma_common_pareto(paper_root,staci_root,mex_dir,result_dir)
%RUN_BALERMA_COMMON_PARETO Cost vs branch-hop on a fixed top-90 pipe subset.
% The subset is the first 90 physical pipes in the frozen volume ranking.
% In the R38-anchor study all other diameters remain at the feasible
% zero-pipe reference; in the older four-reservoir study they retain the
% original INP diameters.
% The nominal GA uses the same 10--120 m, 0.1--64 in, and consumer chlorine
% constraints as the six full-network searches. No outage solve occurs here.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
if nargin<4 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_sourceentry_v4');
end
if contains(string(result_dir),'r38_anchor')
    cfg=network_config_r38_anchor(network_dir);
    cfg.results_dir=result_dir;
    input_file=cfg.inp_file;
else
    cfg=network_config(network_dir);
    cfg.branch_hop_weighting=balerma_connected_branch_weights(cfg);
    input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
end
ranked=load(fullfile(result_dir,'pipe_rankings.mat'),'ranking');
ranking=ranked.ranking;
q=find(strcmp(ranking.criterion_keys,'volume'),1);
assert(isscalar(q),'Volume ranking is required for the Pareto subset');
selected=double(ranking.orders(1:90,q));
assert(numel(unique(selected))==90 && ...
    all(selected>=1 & selected<=454), ...
    'The fixed Pareto subset must contain 90 unique physical pipes');
ids=string(cfg.design_link_ids(:));
st=StaciModel(input_file);
release=onCleanup(@()st.release());
[link_order,original_full]=wdn.staci_input_link_template( ...
    input_file,st,0.001);
x_original=double(st.getLinkProperty(ids,'diameter_m'))'/0.001;
if isfield(cfg.ranking,'reference_design') && ...
        ~isempty(cfg.ranking.reference_design)
    x_original=double(cfg.ranking.reference_design(:)');
end
assert(numel(x_original)==454,'Expected 454 Balerma physical pipes');
seed_cost=load(fullfile(result_dir,'ranking_cache','cost', ...
    'volume','k_090.mat'),'entry');
seed_branch=load(fullfile(result_dir,'ranking_cache', ...
    'branch_hop_weighted_entropy','volume','k_090.mat'),'entry');
assert(seed_cost.entry.is_feasible && seed_branch.entry.is_feasible, ...
    'Both K=90 volume-ranked endpoint designs must be feasible');
y_cost=double(seed_cost.entry.design_diameters(selected));
y_branch=double(seed_branch.entry.design_diameters(selected));
rng(20261114,'twister');
population=cfg.minimum_diameter+ ...
    (cfg.maximum_diameter-cfg.minimum_diameter)*rand(120,90);
population(1,:)=x_original(selected);
population(2,:)=y_cost;
population(3,:)=y_branch;
for i=1:9
    alpha=i/10;
    population(i+3,:)=(1-alpha)*y_cost+alpha*y_branch;
end
lb=cfg.minimum_diameter*ones(1,90);
ub=cfg.maximum_diameter*ones(1,90);
cache=containers.Map('KeyType','char','ValueType','any');
maximum_wall_seconds=7200;
started=tic;
options=optimoptions('gamultiobj','Display','final', ...
    'PopulationSize',120,'MaxGenerations',250, ...
    'MaxStallGenerations',70,'FunctionTolerance',1e-5, ...
    'ConstraintTolerance',cfg.ga.constraint_tolerance, ...
    'ParetoFraction',0.8,'InitialPopulationMatrix',population, ...
    'UseParallel',false,'OutputFcn',@stop_on_wall);
[y,fitness,exitflag,output]=gamultiobj( ...
    @objective,90,[],[],[],[],lb,ub,@constraints,options);
% Preserve both feasible single-objective subset endpoints in the finite
% archive even if the stochastic GA omits them from its final population.
y=[y;y_cost;y_branch];
fitness=[fitness;objective(y_cost);objective(y_branch)];
rows=cell(size(y,1),1);
violations=zeros(size(y,1),1);
designs=zeros(size(y,1),454);
for k=1:size(y,1)
    designs(k,:)=expand(y(k,:));
    [rows{k},violations(k)]=wdn.evaluate_staci_design( ...
        st,cfg,designs(k,:),link_order,original_full);
end
assert(all(violations<=cfg.ga.constraint_tolerance), ...
    'Pareto archive contains an infeasible nominal Balerma design');
result.network_id='balerma';
result.objectives={'cost','branch_hop_weighted_entropy'};
result.designs=designs;
result.optimizer_values=fitness;
result.cost=cellfun(@(m)m.cost,rows);
result.branch_hop_entropy=cellfun( ...
    @(m)m.branch_hop_weighted_entropy,rows);
result.hydraulic_entropy=cellfun(@(m)m.hydraulic_entropy,rows);
result.chlorine_concentration=cellfun( ...
    @(m)m.chlorine_concentration,rows);
result.chlorine_entropy=cellfun(@(m)m.chlorine_entropy,rows);
result.todini=cellfun(@(m)m.todini,rows);
result.max_constraint_violation=violations;
result.selected_pipe_ids=cellstr(ids(selected));
result.ranking_criterion='volume';
result.branch_hop_weighting_version=cfg.branch_hop_weighting.version;
result.optimized_pipe_count=90;
result.total_pipe_count=454;
result.constraint_set_id=cfg.constraint_set_id;
result.minimum_diameter=cfg.minimum_diameter;
result.maximum_diameter=cfg.maximum_diameter;
result.exitflag=exitflag;
result.output=output;
result.elapsed_time_seconds=toc(started);
result.maximum_wall_seconds=maximum_wall_seconds;
save(fullfile(result_dir,'pareto_cost_branch_hop_top90.mat'), ...
    'result','-v7');
clear release st
    function x=expand(candidate)
        x=x_original;
        x(selected)=candidate;
    end
    function [m,v]=measure(candidate)
        key=sprintf('%.13g,',candidate);
        if isKey(cache,key)
            item=cache(key);m=item.metrics;v=item.violation;return
        end
        try
            [all_metrics,v]=wdn.evaluate_staci_design(st,cfg, ...
                expand(candidate),link_order,original_full);
            % Only the two fitness scalars are needed during GA search.
            % Keeping 454-pipe and 447-node arrays for every candidate
            % would make a long multiobjective run needlessly memory-heavy.
            m=struct('cost',all_metrics.cost, ...
                'branch_hop_weighted_entropy', ...
                all_metrics.branch_hop_weighted_entropy);
        catch
            m=struct('cost',1e12,'branch_hop_weighted_entropy',-1e12);
            v=1e6;
        end
        cache(key)=struct('metrics',m,'violation',v);
    end
    function f=objective(candidate)
        [m,~]=measure(candidate);
        f=[m.cost/1e6,-m.branch_hop_weighted_entropy];
    end
    function [c,ceq]=constraints(candidate)
        [~,c]=measure(candidate);
        ceq=[];
    end
    function [state,options_now,optchanged]=stop_on_wall( ...
            options_now,state,flag) %#ok<INUSD>
        optchanged=false;
        if toc(started)>=maximum_wall_seconds
            state.StopFlag='Balerma Pareto wall-time guard';
        end
    end
end
