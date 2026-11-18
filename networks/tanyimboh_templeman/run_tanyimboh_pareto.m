function result = run_tanyimboh_pareto(paper_root,staci_root,mex_dir,results_dir,figure_dir)
%RUN_TANYIMBOH_PARETO Cost vs branch-hop entropy with common constraints.
% This is a separate eight-diameter gamultiobj search. Each candidate uses
% one resident STACI model and the same pressure/chlorine constraint set as
% the six single-objective searches. Saved single-objective vectors seed it.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
nd=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(nd);
cfg=network_config(nd);
if nargin>=4 && ~isempty(results_dir)
    cfg.results_dir=char(results_dir);
end
cfg.branch_hop_weighting=tanyimboh_branch_hop_weights(cfg);
input_file=fullfile(nd,'input','network_staci_fixed_load.inp');
st=StaciModel(input_file);
release=onCleanup(@()st.release());
[link_order,original]=wdn.staci_input_link_template(input_file,st,0.001);
seeds=[];
for name=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
        "chlorine_concentration","chlorine_entropy","todini"]
    item=load(fullfile(cfg.results_dir,name+".mat"),'result');
    seeds(end+1,:)=double(item.result.design_diameters(:)'); %#ok<AGROW>
end
n=numel(cfg.design_link_ids);
lb=cfg.minimum_diameter*ones(1,n);
ub=cfg.maximum_diameter*ones(1,n);
rng(20261113,'twister');
pop=lb+rand(120,n).*(ub-lb);
pop(1:size(seeds,1),:)=seeds;
cache=containers.Map('KeyType','char','ValueType','any');
options=optimoptions('gamultiobj','Display','final', ...
    'PopulationSize',120,'MaxGenerations',200, ...
    'MaxStallGenerations',50,'FunctionTolerance',1e-5, ...
    'ConstraintTolerance',cfg.ga.constraint_tolerance, ...
    'ParetoFraction',0.8,'InitialPopulationMatrix',pop, ...
    'UseParallel',false);
started=tic;
[x,fitness,exitflag,output]=gamultiobj(@objective,n,[],[],[],[], ...
    lb,ub,@constraints,options);
m=cell(size(x,1),1);v=zeros(size(x,1),1);
for k=1:size(x,1)
    [m{k},v(k)]=wdn.evaluate_staci_design(st,cfg,x(k,:),link_order,original);
end
assert(all(v<=cfg.ga.constraint_tolerance),'Infeasible Pareto design');
result.network_id=cfg.id;
result.objectives={'cost','branch_hop_weighted_entropy'};
result.designs=x;
result.optimizer_values=fitness;
result.metrics=[m{:}]';
result.cost=cellfun(@(q)q.cost,m);
result.branch_hop_entropy=cellfun(@(q)q.branch_hop_weighted_entropy,m);
result.hydraulic_entropy=cellfun(@(q)q.hydraulic_entropy,m);
result.chlorine_concentration=cellfun(@(q)q.chlorine_concentration,m);
result.chlorine_entropy=cellfun(@(q)q.chlorine_entropy,m);
result.todini=cellfun(@(q)q.todini,m);
result.max_constraint_violation=v;
result.exitflag=exitflag;result.output=output;
result.elapsed_time_seconds=toc(started);
result.constraint_set_id='pressure_10_120m_chlorine_mass_split_v2';
save(fullfile(cfg.results_dir,'pareto_cost_branch_hop.mat'),'result','-v7');
if nargin<5 || isempty(figure_dir)
    figure_dir=fullfile(nd,'figures_staci_10_120_clsplit_v2');
end
if ~isfolder(figure_dir),mkdir(figure_dir);end
wdn.plot_cost_entropy_front(result,cfg, ...
    fullfile(figure_dir,'tanyimboh_cost_branch_hop_pareto.png'));
clear release st
    function [metric,violation]=measure(candidate)
        key=sprintf('%.13g,',candidate);
        if isKey(cache,key)
            item=cache(key);metric=item.m;violation=item.v;return
        end
        try
            [metric,violation]=wdn.evaluate_staci_design( ...
                st,cfg,candidate,link_order,original);
        catch
            metric=struct('cost',1e12,'branch_hop_weighted_entropy',-1e12);
            violation=1e6;
        end
        cache(key)=struct('m',metric,'v',violation);
    end
    function f=objective(candidate)
        [metric,~]=measure(candidate);
        f=[metric.cost/1e6,-metric.branch_hop_weighted_entropy];
    end
    function [c,ceq]=constraints(candidate)
        [~,c]=measure(candidate);ceq=[];
    end
end
