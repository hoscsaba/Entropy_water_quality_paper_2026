function result = optimize_staci_cost_entropy_front(cfg, input_file)
%OPTIMIZE_STACI_COST_ENTROPY_FRONT Cost versus fixed branching-hop entropy.
st = StaciModel(input_file);
cleanup = onCleanup(@() st.release());
[link_order, full_original] = wdn.staci_input_link_template( ...
    input_file,st,0.0254);
full_original = full_original(:)';
design_ids = string(cfg.design_link_ids(:));
x_original = double(st.getLinkProperty(design_ids,'diameter_m'))'/0.0254;
[~,di] = ismember(design_ids,link_order);
full_original(di) = x_original;
nvars = numel(design_ids);
lb = cfg.minimum_diameter*ones(1,nvars);
ub = cfg.maximum_diameter*ones(1,nvars);
seed_names = ["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
seeds = zeros(numel(seed_names),nvars);
for k=1:numel(seed_names)
    saved=load(fullfile(cfg.results_dir,seed_names(k)+'.mat'),'result');
    seeds(k,:)=saved.result.design_diameters;
end
branch_saved=load(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
weighting=branch_saved.result.branch_hop_weighting;
initial_status=st.solveHydraulics();
assert(initial_status.converged,'Initial Anytown hydraulics failed');
reference_nodes=st.nodeResults();
node_ids=string(reference_nodes.id(:));
[found,wi]=ismember(node_ids,string(weighting.node_ids(:)));
assert(all(found),'Branch-hop weight node IDs differ from model');
branch_weights=double(weighting.weights(wi));
% Seed the under-resolved middle between the two single-objective endpoints.
for alpha=linspace(0.025,0.975,39)
    seeds=[seeds;(1-alpha)*seeds(1,:)+alpha*seeds(3,:)]; %#ok<AGROW>
end
seeds=unique(min(max(seeds,lb),ub),'rows','stable');
if size(seeds,1)>cfg.multiobjective.population_size
    remaining=cfg.multiobjective.population_size-numel(seed_names);
    ix=round(linspace(numel(seed_names)+1,size(seeds,1),remaining));
    seeds=seeds([1:numel(seed_names),ix],:);
end
rng(cfg.multiobjective.cost_entropy_random_seed,'twister');
cache=containers.Map('KeyType','char','ValueType','any');
options=optimoptions('gamultiobj', ...
    'Display','final', ...
    'PopulationSize',cfg.multiobjective.population_size, ...
    'MaxGenerations',cfg.multiobjective.max_generations, ...
    'MaxStallGenerations',cfg.multiobjective.max_stall_generations, ...
    'FunctionTolerance',cfg.multiobjective.function_tolerance, ...
    'ConstraintTolerance',cfg.ga.constraint_tolerance, ...
    'ParetoFraction',cfg.multiobjective.pareto_fraction, ...
    'CrossoverFraction',0.8, ...
    'MutationFcn',@mutationadaptfeasible, ...
    'InitialPopulationMatrix',seeds, ...
    'UseParallel',false);
[designs,values,exitflag,output,population,scores]=gamultiobj( ...
    @fitness,nvars,[],[],[],[],lb,ub,@constraints,options);
n=size(designs,1);
assert(n>=2,'STACI Pareto archive contains fewer than two points');
metrics=cell(n,1);
violation=zeros(n,1);
for k=1:n
    [metrics{k},violation(k)]=wdn.evaluate_staci_design( ...
        st,cfg,designs(k,:),link_order,full_original);
    metrics{k}.branch_hop_entropy=wdn.source_distance_weighted_entropy( ...
        st,cfg,branch_weights);
end
assert(all(violation<=cfg.ga.constraint_tolerance), ...
    'STACI Pareto archive contains an infeasible design');
cost=cellfun(@(m)m.cost,metrics);
[~,order]=sort(cost);
designs=designs(order,:);values=values(order,:);
metrics=metrics(order);violation=violation(order);
cost=cost(order);
result.network_id=cfg.id;
result.objectives={'cost','branch_hop_weighted_entropy'};
result.design_link_ids=cfg.design_link_ids;
result.designs=designs;
result.optimizer_values=values;
result.metrics=[metrics{:}]';
result.cost=cost;
result.hydraulic_entropy=cellfun(@(m)m.hydraulic_entropy,metrics);
result.branch_hop_entropy=cellfun(@(m)m.branch_hop_entropy,metrics);
result.chlorine_concentration=cellfun(@(m)m.chlorine_concentration,metrics);
result.chlorine_entropy=cellfun(@(m)m.chlorine_entropy,metrics);
node_ids=string(metrics{1}.node_ids(:));
[~,pi]=ismember(string(cfg.pressure_node_ids(:)),node_ids);
[~,ai]=ismember(string(cfg.pressure_anchor_node_ids(:)),node_ids);
result.minimum_pressure=cellfun(@(m)min(m.pressures(pi)),metrics);
if isempty(ai)
    result.anchor_head_deviation=nan(numel(metrics),1);
else
    result.anchor_head_deviation=cellfun(@(m)max(abs( ...
        reshape(m.heads(ai),[],1)- ...
        cfg.pressure_anchor_target_heads(:))),metrics);
end
result.max_constraint_violation=violation;
result.exitflag=exitflag;result.output=output;
result.final_population=population;result.final_scores=scores;
result.optimizer='matlab_gamultiobj_staci_mex';
result.model='staci_fixed_load';
result.random_seed=cfg.multiobjective.cost_entropy_random_seed;
result.branch_hop_weighting=weighting;
result.cost_fitness_scale=1e6;
result.created_at=datetime('now','TimeZone','local');

    function [m,v]=evaluate_cached(x)
        key=sprintf('%.13g,',x);
        if isKey(cache,key)
            item=cache(key);m=item.metrics;v=item.violation;return;
        end
        try
            [m,v]=wdn.evaluate_staci_design(st,cfg,x, ...
                link_order,full_original);
            m.branch_hop_entropy=wdn.source_distance_weighted_entropy( ...
                st,cfg,branch_weights);
        catch
            m=struct('cost',1e12,'branch_hop_entropy',-1e12);
            v=1e6;
        end
        cache(key)=struct('metrics',m,'violation',v);
    end

    function f=fitness(x)
        [m,~]=evaluate_cached(x);
        f=[m.cost/1e6,-m.branch_hop_entropy];
    end

    function [c,ceq]=constraints(x)
        [~,c]=evaluate_cached(x);
        ceq=[];
    end
end
