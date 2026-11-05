function study = optimize_staci_ranked_subsets(cfg, ranking, objective, k_values, full_result, input_file)
%OPTIMIZE_STACI_RANKED_SUBSETS Resumable nested GA on STACI fixed-load model.
% Each (objective, criterion, K) has its own cache entry. Extending K never
% repeats earlier optimizations. All candidate solves use one resident MEX.
objective = string(objective);
names = {'cost','hydraulic_entropy','chlorine_concentration', ...
    'chlorine_entropy','todini'};
assert(ismember(objective, string(names)), 'Unknown objective');
chlorine_objective = ismember(objective, ...
    ["chlorine_concentration","chlorine_entropy"]);
st = StaciModel(input_file);
cleanup = onCleanup(@() st.release());
design_ids = string(cfg.design_link_ids(:));
if strcmp(cfg.id, 'anytown'), scale = 0.0254;
else, scale = 0.001;
end
x_original = double(st.getLinkProperty(design_ids, 'diameter_m'))' / scale;
[~,pressure_index] = ismember(string(cfg.pressure_node_ids(:)),st.nodeIds());
assert(all(pressure_index>0),'Configured pressure node missing');
lengths = double(st.getLinkProperty(design_ids,'length_m'))';
if strcmp(cfg.id,'anytown'), lengths = lengths / 0.3048; end
[link_order, full_original] = wdn.staci_input_link_template( ...
    input_file, st, scale);
full_original = full_original(:)';
[~, design_positions] = ismember(design_ids, link_order);
full_original(design_positions) = x_original;
k_values = double(k_values(:)');
n_criteria = numel(ranking.criterion_keys);
metrics = nan(n_criteria,numel(k_values),5);
designs = nan(n_criteria,numel(k_values),numel(x_original));
violations = nan(n_criteria,numel(k_values));
is_feasible = false(n_criteria,numel(k_values));
elapsed_seconds = zeros(n_criteria,numel(k_values));
[original_metrics, original_violation] = wdn.evaluate_staci_design( ...
    st,cfg,x_original,link_order,full_original);
if chlorine_objective
    original_violation = max(original_violation, ...
        0.2 - original_metrics.minimum_consumer_chlorine_mgL);
end
study_started = tic;
if isfield(cfg.ranking,'max_generations')
    ranking_maxgen = cfg.ranking.max_generations;
else
    ranking_maxgen = cfg.ga.max_generations;
end
if isfield(cfg.ranking,'max_stall_generations')
    ranking_stall = cfg.ranking.max_stall_generations;
else
    ranking_stall = cfg.ga.max_stall_generations;
end
for q = 1:n_criteria
    current_feasible = [];
    for j = 1:numel(k_values)
        if toc(study_started) > 7200
            error('wdn:RankingWallBudget', ...
                'STACI ranking objective exceeded two hours; completed cache entries are reusable.');
        end
        k = k_values(j);
        cache_dir = fullfile(cfg.results_dir,'ranking_cache',char(objective), ...
            ranking.criterion_keys{q});
        if ~isfolder(cache_dir), mkdir(cache_dir); end
        cache_file = fullfile(cache_dir,sprintf('k_%03d.mat',k));
        signature_base = sprintf('staci-v1|%s|%s|%s|%d|%d|%d|%d|%d|%.9g', ...
            cfg.id,objective,ranking.criterion_keys{q},k, ...
            cfg.ga.random_seed,cfg.ga.population_size, ...
            ranking_maxgen,ranking_stall, ...
            sum(ranking.orders(:,q).*(1:numel(design_ids))'));
        signature = sprintf('%s|%.9g',signature_base, ...
            sum(full_result.design_diameters.^2));
        if isfile(cache_file) && k < numel(x_original)
            saved = load(cache_file,'entry');
            % A better full-network seed does not invalidate an earlier
            % feasible subset calculation. Only K=N must follow the latest
            % full result; the independently stored K<N points are reused.
            assert(startsWith(saved.entry.cache_signature, ...
                [signature_base '|']), ...
                'Incompatible STACI ranking cache: %s',cache_file);
            entry = saved.entry;
        else
            started = tic;
            if k == 0
                entry.design_diameters = x_original;
                entry.metrics = original_metrics;
                entry.max_constraint_violation = original_violation;
                entry.is_feasible = original_violation <= cfg.ga.constraint_tolerance;
                entry.exitflag = NaN; entry.generations = 0;
            elseif k == numel(x_original)
                entry.design_diameters = full_result.design_diameters;
                entry.metrics = full_result.metrics;
                entry.max_constraint_violation = full_result.max_constraint_violation;
                entry.is_feasible = entry.max_constraint_violation <= ...
                    cfg.ga.constraint_tolerance;
                entry.exitflag = full_result.exitflag;
                entry.generations = full_result.ga_last_generation;
            else
                selected = ranking.orders(1:k,q)';
                lb = cfg.minimum_diameter*ones(1,k);
                ub = cfg.maximum_diameter*ones(1,k);
                rng(cfg.ga.random_seed,'twister');
                population = lb + rand(cfg.ga.population_size,k).*(ub-lb);
                population(1,:) = x_original(selected);
                population(2,:) = full_result.design_diameters(selected);
                if ~isempty(current_feasible)
                    population(3,:) = current_feasible(selected);
                end
                last_y = [];
                last_metric = struct();
                last_violation = inf;
                best_y = [];
                best_f = inf;
                generations = 0;
                options = optimoptions('ga','Display','off', ...
                    'PopulationSize',cfg.ga.population_size, ...
                    'MaxGenerations',ranking_maxgen, ...
                    'MaxStallGenerations',ranking_stall, ...
                    'FunctionTolerance',cfg.ga.function_tolerance, ...
                    'ConstraintTolerance',cfg.ga.constraint_tolerance, ...
                    'NonlinearConstraintAlgorithm','penalty', ...
                    'InitialPopulationMatrix',population, ...
                    'UseParallel',false,'OutputFcn',@budget_callback);
                [y,~,exitflag,output] = ga(@fitness,k,[],[],[],[], ...
                    lb,ub,@constraint,options);
                candidates = [y(:)';population(1:2,:)];
                if ~isempty(current_feasible)
                    candidates(end+1,:) = current_feasible(selected);
                end
                if ~isempty(best_y), candidates(end+1,:) = best_y; end
                best_candidate = [];
                best_value = inf;
                for candidate_index = 1:size(candidates,1)
                    [value, violation_now] = ...
                        evaluate_y(candidates(candidate_index,:));
                    if violation_now <= cfg.ga.constraint_tolerance && ...
                            value < best_value
                        best_value = value;
                        best_candidate = candidates(candidate_index,:);
                    end
                end
                if isempty(best_candidate)
                    entry.design_diameters = map_design(y);
                    entry.metrics = struct();
                    [~,entry.max_constraint_violation] = evaluate_y(y);
                    entry.is_feasible = false;
                else
                    entry.design_diameters = map_design(best_candidate);
                    x_best = map_design(best_candidate);
                    [entry.metrics,entry.max_constraint_violation] = ...
                        wdn.evaluate_staci_design(st,cfg,x_best, ...
                        link_order,full_original);
                    if chlorine_objective
                        entry.max_constraint_violation = max( ...
                            entry.max_constraint_violation, ...
                            0.2-entry.metrics.minimum_consumer_chlorine_mgL);
                    end
                    entry.is_feasible = true;
                end
                entry.exitflag = exitflag;
                entry.generations = output.generations;
            end
            entry.cache_signature = signature;
            entry.network_id = cfg.id;
            entry.objective = char(objective);
            entry.criterion_key = ranking.criterion_keys{q};
            entry.k = k;
            entry.elapsed_seconds = toc(started);
            entry.created_at = datetime('now','TimeZone','local');
            save(cache_file,'entry','-v7');
        end
        designs(q,j,:) = entry.design_diameters;
        violations(q,j) = entry.max_constraint_violation;
        is_feasible(q,j) = entry.is_feasible;
        elapsed_seconds(q,j) = entry.elapsed_seconds;
        if k == 0 || entry.is_feasible
            for m = 1:5
                metrics(q,j,m) = entry.metrics.(names{m});
            end
        end
        if entry.is_feasible, current_feasible = entry.design_diameters; end
        fprintf('%s/%s k=%d feasible=%d gen=%d elapsed=%.1fs\n', ...
            cfg.id,objective,k,entry.is_feasible,entry.generations, ...
            entry.elapsed_seconds);
    end
end
study.network_id = cfg.id;
study.objective = char(objective);
study.model = 'staci_fixed_load';
study.pressure_anchor_method = isfield(cfg,'pressure_anchor_node_ids') && ...
    ~isempty(cfg.pressure_anchor_node_ids);
study.k = k_values;
study.criterion_keys = ranking.criterion_keys;
study.criterion_labels = ranking.criterion_labels;
study.metric_names = names;
study.metrics = metrics;
study.designs = designs;
study.max_constraint_violations = violations;
study.is_feasible = is_feasible;
study.elapsed_seconds = elapsed_seconds;
study.original_design = x_original;
study.original_metrics = original_metrics;
study.original_constraint_violation = original_violation;
study.full_result_objective = full_result.objective;
study.created_at = datetime('now','TimeZone','local');

    function x = map_design(y)
        x = x_original;
        x(selected) = double(y(:)');
    end

    function [f,v,m] = evaluate_y(y)
        y = double(y(:)');
        if isequal(y,last_y)
            f = fitness_from_metric(last_metric);
            v = last_violation;
            m = last_metric;
            return;
        end
        try
            x = map_design(y);
            [m,v] = fast_measure(x);
            f = fitness_from_metric(m);
        catch
            m = struct(); v = 1e6; f = 1e12;
        end
        if v <= cfg.ga.constraint_tolerance && f < best_f
            best_f = f; best_y = y;
        end
        last_y = y; last_metric = m; last_violation = v;
    end

    function [m,v] = fast_measure(x)
        % Candidate solves only the optimized objective and its constraints.
        % The other four metrics, including chlorine when not optimized,
        % are computed once for each selected feasible cache entry.
        st.setLinkProperty(design_ids,'diameter_m',x(:)*scale);
        status=st.solveHydraulics();
        assert(status.converged,'STACI candidate hydraulics failed');
        nodes=st.nodeResults();
        pressure=double(nodes.pressure_head_m(:));
        if strcmp(cfg.id,'anytown')
            pressure=pressure/(0.3048*cfg.pressure_to_head);
        end
        c=cfg.minimum_pressure-pressure(pressure_index);
        if isfinite(cfg.maximum_pressure)
            c=[c;pressure(pressure_index)-cfg.maximum_pressure];
        end
        if isfield(cfg,'pressure_anchor_node_ids') && ...
                ~isempty(cfg.pressure_anchor_node_ids)
            [found,ix]=ismember(string(cfg.pressure_anchor_node_ids(:)), ...
                string(nodes.id(:)));
            assert(all(found),'STACI pressure anchor missing');
            anchor_ft=double(nodes.total_head_m(ix))/0.3048;
            c=[c;abs(anchor_ft(:)-cfg.pressure_anchor_target_heads(:)) ...
                -cfg.pressure_anchor_head_tolerance];
        end
        m=struct();
        switch objective
            case "cost"
                m.cost=wdn.pipe_cost(x,lengths,cfg);
            case "hydraulic_entropy"
                m.hydraulic_entropy=wdn.staci_flow_entropy(st,cfg,[]);
            otherwise
                quality=st.solveSteadyQuality('chemical');
                chlorine=1000*double(quality.node_concentration_kgm3(:));
                [found,qi]=ismember(string(cfg.quality_node_ids(:)), ...
                    string(quality.node_ids(:)));
                assert(all(found),'STACI quality assessment node missing');
                consumer=double(nodes.demand_m3s(:)) > ...
                    pi/4*0.010^2*0.01;
                [found,ci]=ismember(string(nodes.id(consumer)), ...
                    string(quality.node_ids(:)));
                assert(all(found),'STACI material-demand node missing');
                c=[c;0.2-chlorine(ci)];
                if objective=="chlorine_concentration"
                    m.chlorine_concentration=sum(chlorine(qi).^2);
                else
                    node_chlorine=zeros(numel(nodes.id),1);
                    [~,ix]=ismember(string(nodes.id(:)), ...
                        string(quality.node_ids(:)));
                    node_chlorine(:)=chlorine(ix);
                    m.chlorine_entropy=wdn.staci_flow_entropy( ...
                        st,cfg,node_chlorine);
                end
        end
        v=max([0;c(:)]);
    end

    function f = fitness_from_metric(m)
        if ~isfield(m,char(objective))
            f = 1e12;
        elseif objective == "cost"
            f = m.cost;
        else
            f = -m.(char(objective));
        end
    end

    function f = fitness(y)
        [f,~] = evaluate_y(y);
    end

    function [inequality,ceq] = constraint(y)
        [~,inequality] = evaluate_y(y);
        ceq = [];
    end

    function [ga_state,opts,changed] = budget_callback(opts,ga_state,flag)
        changed = false;
        if strcmp(flag,'iter'), generations = ga_state.Generation; end
        if toc(study_started) > 7200
            ga_state.StopFlag = 'ranking study wall-clock budget reached';
        end
    end
end
