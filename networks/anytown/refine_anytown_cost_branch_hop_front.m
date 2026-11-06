function result = refine_anytown_cost_branch_hop_front(paper_root,staci_root,mex_dir)
%REFINE_ANYTOWN_COST_BRANCH_HOP_FRONT Fill sparse middle cost bands in Fig. 7.
% This resumes the saved multiobjective archive. Each cost cap is independent
% and may be extended by adding caps; completed caps in result.refinement
% are skipped. Candidate evaluations reuse one in-memory STACI model.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
cfg=network_config(network_dir);
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
archive_file=fullfile(cfg.results_dir,'multiobjective_cost_entropy.mat');
loaded=load(archive_file,'result');
result=loaded.result;
assert(isequal(string(result.objectives), ...
    ["cost","branch_hop_weighted_entropy"]), ...
    'A cost--branching-hop archive is required');
st=StaciModel(input_file);
cleanup=onCleanup(@() st.release());
[link_order,original]=wdn.staci_input_link_template(input_file,st,0.0254);
ids=string(cfg.design_link_ids(:));
nvars=numel(ids);
status=st.solveHydraulics();
assert(status.converged,'Initial hydraulics failed');
nodes=st.nodeResults();
weighting=result.branch_hop_weighting;
[found,ix]=ismember(string(nodes.id(:)),string(weighting.node_ids(:)));
assert(all(found),'Frozen branching-hop weights do not match node IDs');
weights=double(weighting.weights(ix));
lb=cfg.minimum_diameter*ones(1,nvars);
ub=cfg.maximum_diameter*ones(1,nvars);
caps=[57.5,58,60,62,64,66,68,69,70,72,74,76,77,78,80,82,84];
% Add new caps to extend the middle without rerunning completed caps.
if ~isfield(result,'refinement')
    result.refinement=struct('cost_cap_million',{},'generations',{}, ...
        'evaluations',{},'best_cost_million',{},'best_branch_entropy',{}, ...
        'accepted',{});
end
for cap=caps
    if any([result.refinement.cost_cap_million]==cap)
        continue;
    end
    rng(20261106+round(cap*10),'twister');
    below=find(result.cost(:)/1e6<=cap);
    assert(~isempty(below),'No feasible seed below cost cap');
    [~,rank]=sort(result.branch_hop_entropy(below),'descend');
    chosen=below(rank(1:min(55,numel(rank))));
    seeds=double(result.designs(chosen,:));
    above=find(result.cost(:)/1e6>cap,1,'first');
    if ~isempty(above)
        lower=chosen(1);
        for alpha=linspace(0.1,0.9,9)
            seeds(end+1,:)=(1-alpha)*result.designs(lower,:) + ...
                alpha*result.designs(above,:); %#ok<AGROW>
        end
    end
    cache=containers.Map('KeyType','char','ValueType','any');
    opts=optimoptions('ga','Display','final','PopulationSize',100, ...
        'MaxGenerations',250,'MaxStallGenerations',70, ...
        'FunctionTolerance',1e-6, ...
        'ConstraintTolerance',cfg.ga.constraint_tolerance, ...
        'NonlinearConstraintAlgorithm','penalty', ...
        'InitialPopulationMatrix',seeds,'UseParallel',false);
    [candidate,~,~,output]=ga(@fitness,nvars,[],[],[],[], ...
        lb,ub,@constraints,opts);
    [candidate_metrics,violation]=evaluate(candidate,true);
    accepted=violation<=cfg.ga.constraint_tolerance && ...
        candidate_metrics.cost/1e6<=cap+cfg.ga.constraint_tolerance;
    if accepted
        result.designs(end+1,:)=candidate;
        result.metrics(end+1,1)=candidate_metrics;
        result.cost(end+1,1)=candidate_metrics.cost;
        result.branch_hop_entropy(end+1,1)= ...
            candidate_metrics.branch_hop_entropy;
        result.hydraulic_entropy(end+1,1)= ...
            candidate_metrics.hydraulic_entropy;
        result.chlorine_concentration(end+1,1)= ...
            candidate_metrics.chlorine_concentration;
        result.chlorine_entropy(end+1,1)= ...
            candidate_metrics.chlorine_entropy;
        result.max_constraint_violation(end+1,1)=violation;
        result.optimizer_values(end+1,:)=[candidate_metrics.cost/1e6, ...
            -candidate_metrics.branch_hop_entropy];
    end
    record=struct('cost_cap_million',cap, ...
        'generations',output.generations, ...
        'evaluations',output.funccount, ...
        'best_cost_million',candidate_metrics.cost/1e6, ...
        'best_branch_entropy',candidate_metrics.branch_hop_entropy, ...
        'accepted',accepted);
    result.refinement(end+1)=record;
    fprintf('Cap %.1f: cost %.4f, branch %.7f, accepted %d, %d evaluations\n', ...
        cap,record.best_cost_million,record.best_branch_entropy, ...
        accepted,record.evaluations);
    save(archive_file,'result','-v7');
end
% A strictly increasing entropy envelope in ascending cost is the
% nondominated subset of this two-objective, feasible archive.
[~,order]=sort(result.cost(:));
keep=false(numel(order),1);
best=-inf;
for k=1:numel(order)
    i=order(k);
    if result.branch_hop_entropy(i)>best+1e-9
        keep(i)=true;
        best=result.branch_hop_entropy(i);
    end
end
result.designs=result.designs(keep,:);
result.metrics=result.metrics(keep);
result.cost=result.cost(keep);
result.branch_hop_entropy=result.branch_hop_entropy(keep);
result.hydraulic_entropy=result.hydraulic_entropy(keep);
result.chlorine_concentration=result.chlorine_concentration(keep);
result.chlorine_entropy=result.chlorine_entropy(keep);
result.max_constraint_violation=result.max_constraint_violation(keep);
result.optimizer_values=result.optimizer_values(keep,:);
[~,order]=sort(result.cost(:));
result.designs=result.designs(order,:);
result.metrics=result.metrics(order);
result.cost=result.cost(order);
result.branch_hop_entropy=result.branch_hop_entropy(order);
result.hydraulic_entropy=result.hydraulic_entropy(order);
result.chlorine_concentration=result.chlorine_concentration(order);
result.chlorine_entropy=result.chlorine_entropy(order);
result.max_constraint_violation=result.max_constraint_violation(order);
result.optimizer_values=result.optimizer_values(order,:);
metric_node_ids=string(result.metrics(1).node_ids(:));
[found_pressure,pi]=ismember(string(cfg.pressure_node_ids(:)),metric_node_ids);
[found_anchor,ai]=ismember(string(cfg.pressure_anchor_node_ids(:)),metric_node_ids);
assert(all(found_pressure)&all(found_anchor),'Assessment node missing');
result.minimum_pressure=arrayfun(@(m)min(m.pressures(pi)),result.metrics(:));
result.anchor_head_deviation=arrayfun(@(m)max(abs( ...
    m.heads(ai)-cfg.pressure_anchor_target_heads(:))),result.metrics(:));
save(archive_file,'result','-v7');
audit=table((1:numel(result.cost))',result.cost(:)/1e6, ...
    result.branch_hop_entropy(:),result.hydraulic_entropy(:), ...
    result.chlorine_concentration(:),result.chlorine_entropy(:), ...
    result.minimum_pressure(:),result.anchor_head_deviation(:), ...
    result.max_constraint_violation(:), ...
    'VariableNames',{'RankByCost','CostMillion','BranchHopEntropy', ...
    'FlowEntropy','ChlorineConcentrationObjective','ChlorineEntropy', ...
    'MinimumConsumerPressure_psi','MaximumAnchorHeadDeviation_ft', ...
    'MaximumNominalConstraintViolation'});
writetable(audit,fullfile(cfg.results_dir, ...
    'multiobjective_cost_branch_hop_archive.csv'));
writetable(struct2table(result.refinement),fullfile(cfg.results_dir, ...
    'multiobjective_cost_branch_hop_caps.csv'));
% Materialize the highest-score archive endpoint for an independent
% EPANET replay without replacing the separately reported six-design run.
front=result;
saved_single=load(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
result=saved_single.result;
result.design_diameters=front.designs(end,:);
result.metrics=front.metrics(end);
result.full_diameters=front.metrics(end).full_diameters;
result.max_constraint_violation=front.max_constraint_violation(end);
result.incumbent_source='cost-capped Pareto archive endpoint';
result.optimizer='matlab_gamultiobj_plus_cost_capped_ga';
result.ga_last_generation=NaN;
result.exitflag=NaN;
result.elapsed_time_seconds=NaN;
result.output=struct('message', ...
    'Derived from the saved cost--branching-hop Pareto archive');
save(fullfile(cfg.results_dir,'pareto_branch_hop_endpoint.mat'), ...
    'result','-v7');
result=front;
figure_file=fullfile(cfg.figures_dir,'figure7_cost_entropy.png');
wdn.plot_cost_entropy_front(result,cfg,figure_file);
generated=fullfile(paper_root,'manuscript','generated','figures');
copyfile(figure_file,fullfile(generated,'figure7_cost_entropy.png'),'f');
copyfile(replace(figure_file,'.png','.svg'), ...
    fullfile(generated,'figure7_cost_entropy.svg'),'f');
fprintf('Refined nondominated archive: %d points\n',numel(result.cost));

    function [m,v]=evaluate(x,full_metrics)
        if nargin<2,full_metrics=false;end
        key=sprintf('%.13g,',x);
        if ~full_metrics && isKey(cache,key)
            item=cache(key);m=item.metrics;v=item.violation;return;
        end
        try
            [m,v]=wdn.evaluate_staci_design(st,cfg,x,link_order,original);
            m.branch_hop_entropy=wdn.source_distance_weighted_entropy( ...
                st,cfg,weights);
        catch
            m=struct('cost',1e12,'branch_hop_entropy',-1e12);
            v=1e6;
        end
        if ~full_metrics
            cache(key)=struct('metrics',m,'violation',v);
        end
    end
    function f=fitness(x)
        [m,~]=evaluate(x);
        f=-m.branch_hop_entropy;
    end
    function [c,ceq]=constraints(x)
        [m,v]=evaluate(x);
        c=[v;m.cost/1e6-cap];
        ceq=[];
    end
end
