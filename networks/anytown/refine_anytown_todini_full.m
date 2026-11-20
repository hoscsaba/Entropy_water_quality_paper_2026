function result = refine_anytown_todini_full( ...
        paper_root, staci_root, mex_dir, output_file, seed_file)
%REFINE_ANYTOWN_TODINI_FULL Continue Todini optimization from a ranked seed.
%   RESULT = REFINE_ANYTOWN_TODINI_FULL(PAPER_ROOT,STACI_ROOT,MEX_DIR) returns
%   a proposed full-network result without writing a MAT file. Pass an
%   OUTPUT_FILE outside the released result directory to save a reviewable
%   candidate; this function will not overwrite the released todini.mat.
%
%   The default seed is the feasible K=35 entropy-sensitivity checkpoint
%   produced by REFINE_ANYTOWN_TODINI_RANKINGS. All 38 distribution-pipe
%   diameters are then free in a constrained SQP search. Hydraulics and
%   stationary chlorine are evaluated in one resident STACI model per
%   candidate. A second, fresh model checks the seed and accepted endpoint.
%   The former GA result and its stopping metadata are retained, while
%   POST_GA_REFINEMENT explicitly records the additional SQP stage.
%
%   Example (review before replacing the released result):
%       p = '/path/to/Entropy_water_quality_paper_2026';
%       s = '/path/to/staci';
%       m = fullfile(s,'build-matlab','Matlab');
%       proposed = refine_anytown_todini_full(p,s,m, ...
%           fullfile(tempdir,'anytown_todini_candidate.mat'));

if nargin < 1 || isempty(paper_root)
    paper_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin < 2 || isempty(staci_root)
    error('Pass the STACI checkout path as staci_root.');
end
if nargin < 3 || isempty(mex_dir)
    mex_dir = fullfile(staci_root,'build-matlab','Matlab');
end
if nargin < 4, output_file = ''; end
network_dir = fullfile(paper_root,'networks','anytown');
result_dir = fullfile(network_dir,'results_staci_anchor_replay');
released_file = fullfile(result_dir,'todini.mat');
if nargin < 5 || isempty(seed_file)
    seed_file = fullfile(result_dir,'todini_local_refinement_cache', ...
        'entropy_sensitivity_k_035.mat');
end
assert(isfile(seed_file) && isfile(released_file), ...
    'The K=35 checkpoint and released Todini result are required.');
if ~isempty(output_file)
    assert(~strcmp(char(output_file),released_file), ...
        'Write the candidate to staging, then promote it after review.');
end
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);

% Reproduce the nominal anchor variant without regenerating its INP file.
cfg = network_config(network_dir);
cfg.inp_file = fullfile(network_dir,'input','network_anchor_replay.inp');
cfg.pressure_to_head = 2.30787;
cfg.ga.feasible_interpolation_to_upper = 0;
cfg.ga.anchor_numerical_guard_ft = 0.02;
cfg.ga.pressure_numerical_guard_m = 0.02;
assert(isfile(cfg.inp_file),'Anytown nominal anchor INP is missing.');
loaded = load(fullfile(result_dir,'branch_hop_weighted_entropy.mat'), ...
    'result');
cfg.branch_hop_weighting = loaded.result.branch_hop_weighting;

loaded = load(seed_file,'audit');
seed = loaded.audit;
ids = string(cfg.design_link_ids(:));
n = numel(ids);
x_seed = double(seed.chosen_x(:));
assert(n == 38 && numel(x_seed) == n && numel(seed.selected) == 35, ...
    'Checkpoint is not a 35-of-38 Anytown diameter vector.');
assert(all(x_seed >= cfg.minimum_diameter) && ...
    all(x_seed <= cfg.maximum_diameter), ...
    'The ranked seed exceeds the published diameter bounds.');
loaded = load(released_file,'result');
old = loaded.result;
assert(strcmp(old.objective,'todini') && ...
    strcmp(old.constraint_set_id, ...
        'pressure_10_120m_chlorine_mass_split_v2'), ...
    'The released Todini result used another objective or constraint set.');
assert(isequal(string(old.design_link_ids(:)),ids), ...
    'The released Todini diameter order differs from the nominal INP.');
if isfield(old,'post_ga_refinement') && ...
        isfield(old.post_ga_refinement,'prior_ga_diameters')
    x_ga = double(old.post_ga_refinement.prior_ga_diameters(:));
else
    x_ga = double(old.design_diameters(:));
end
assert(numel(x_ga) == n,'Stored original GA vector has the wrong width.');

loaded = load(fullfile(result_dir,'pipe_rankings.mat'),'ranking');
ranking = loaded.ranking;
criterion = find(strcmp(string(ranking.criterion_keys), ...
    'entropy_sensitivity'),1);
assert(isscalar(criterion) && ...
    isequal(double(seed.selected(:)), ...
        double(ranking.orders(1:35,criterion))), ...
    'K=35 seed selection differs from the current entropy-sensitivity ranking.');

st = StaciModel(cfg.inp_file);
release_st = onCleanup(@()st.release());
x_initial = double(st.getLinkProperty(ids,'diameter_m'))/0.0254;
assert(numel(ranking.reference_design) == n && ...
    max(abs(double(ranking.reference_design(:))-x_initial(:))) < 1e-8, ...
    'Saved pipe ranking reference differs from the current nominal input.');
fixed = setdiff((1:n)',double(seed.selected(:)));
assert(all(abs(x_seed(fixed)-x_initial(fixed)) < 1e-8), ...
    'The K=35 checkpoint does not match the current initial vector.');
[link_order,original] = wdn.staci_input_link_template( ...
    cfg.inp_file,st,0.0254);
[seed_metrics,seed_violation] = fresh_check(x_seed);
assert(seed_violation <= cfg.ga.constraint_tolerance, ...
    'The K=35 seed fails fresh nominal pressure/chlorine constraints.');
[ga_metrics,ga_violation] = fresh_check(x_ga);
assert(ga_violation <= cfg.ga.constraint_tolerance, ...
    'The stored original GA vector fails fresh nominal constraints.');
assert(seed_metrics.todini > ga_metrics.todini, ...
    'The ranked K=35 seed does not improve the original full-GA result.');
[current_metrics,current_violation] = fresh_check(old.design_diameters(:));
assert(current_violation <= cfg.ga.constraint_tolerance, ...
    'The currently released Todini vector fails fresh nominal constraints.');

last_x = [];
last_f = [];
last_c = [];
evaluations = 0;
options = optimoptions('fmincon','Algorithm','sqp','Display','off', ...
    'MaxIterations',100,'MaxFunctionEvaluations',4000, ...
    'ConstraintTolerance',1e-6,'OptimalityTolerance',1e-7, ...
    'StepTolerance',1e-9,'FiniteDifferenceType','forward', ...
    'FiniteDifferenceStepSize',0.05);
started = tic;
[x_sqp,~,exitflag,output] = fmincon(@fitness,x_seed, ...
    [],[],[],[],cfg.minimum_diameter*ones(n,1), ...
    cfg.maximum_diameter*ones(n,1),@constraints,options);
elapsed_seconds = toc(started);
[sqp_metrics,sqp_violation] = fresh_check(x_sqp);
if sqp_violation <= cfg.ga.constraint_tolerance && ...
        sqp_metrics.todini > seed_metrics.todini
    chosen_x = x_sqp;
    chosen_metrics = sqp_metrics;
    chosen_violation = sqp_violation;
    chosen_source = 'full_38_pipe_SQP';
else
    chosen_x = x_seed;
    chosen_metrics = seed_metrics;
    chosen_violation = seed_violation;
    chosen_source = 'K35_ranked_SQP_seed';
end
assert(chosen_metrics.todini > ga_metrics.todini && ...
    chosen_violation <= cfg.ga.constraint_tolerance, ...
    'No feasible improvement over the released Todini result.');
if chosen_metrics.todini <= current_metrics.todini + 1e-10
    % Rerunning a published result must never replace it with a lower score
    % or rewrite its original GA and SQP provenance for a numerical tie.
    result = old;
    if ~isempty(output_file)
        folder = fileparts(output_file);
        if ~isempty(folder) && ~isfolder(folder),mkdir(folder);end
        save(output_file,'result','-v7');
    end
    fprintf('Retained released Todini %.12f; repeated full SQP %.12f.\n', ...
        current_metrics.todini,chosen_metrics.todini);
    clear release_st st
    return
end
assert(chosen_metrics.minimum_consumer_chlorine_mgL >= 0.2-1e-6, ...
    'Accepted design violates the consumer chlorine floor.');
link_ids = string(chosen_metrics.link_ids(:));
flows = double(chosen_metrics.flows_m3s(:));
assert(all(abs(flows(ismember(link_ids,["78","80"]))) < 1e-9), ...
    'Nominal pressure-anchor connectors carry water.');
assert(abs(flows(link_ids == "82")-0.282644079872) < 1e-6, ...
    'The nominal pump does not supply all demand.');

% Keep GA generations, evaluation count, output and elapsed time unchanged:
% these fields describe the original GA, not the subsequent SQP search.
result = old;
result.design_diameters = chosen_x(:)';
result.full_diameters = chosen_metrics.full_diameters;
result.metrics = chosen_metrics;
result.max_constraint_violation = chosen_violation;
result.optimizer_value = -chosen_metrics.todini;
result.optimizer = 'matlab_ga_staci_mex_plus_full_sqp';
result.incumbent_source = chosen_source;
result.post_ga_refinement = struct( ...
    'method','fmincon SQP on all 38 pipe diameters', ...
    'seed_file',relative_seed_path(seed_file,paper_root), ...
    'seed_criterion','entropy_sensitivity', ...
    'seed_k',35, ...
    'seed_diameters',x_seed(:)', ...
    'seed_todini',seed_metrics.todini, ...
    'seed_violation',seed_violation, ...
    'prior_ga_todini',ga_metrics.todini, ...
    'prior_ga_diameters',x_ga(:)', ...
    'sqp_todini',sqp_metrics.todini, ...
    'sqp_violation',sqp_violation, ...
    'chosen_source',chosen_source, ...
    'iterations',output.iterations, ...
    'evaluations',evaluations, ...
    'exitflag',exitflag, ...
    'elapsed_seconds',elapsed_seconds, ...
    'constraint_tolerance',options.ConstraintTolerance, ...
    'acceptance_violation_tolerance_m',cfg.ga.constraint_tolerance, ...
    'finite_difference_step_in',0.05, ...
    'refined_at',datetime('now','TimeZone','local'));
if ~isempty(output_file)
    folder = fileparts(output_file);
    if ~isempty(folder) && ~isfolder(folder),mkdir(folder);end
    save(output_file,'result','-v7');
end
fprintf('Todini GA %.12f; ranked K=35 %.12f; full SQP %.12f; chosen %.12f (%s).\n', ...
    ga_metrics.todini,seed_metrics.todini,sqp_metrics.todini, ...
    chosen_metrics.todini,chosen_source);
fprintf('Fresh STACI violation %.3g m; SQP %d iterations, %d evaluations, %.2f s.\n', ...
    chosen_violation,output.iterations,evaluations,elapsed_seconds);
clear release_st st

    function [metrics,violation] = fresh_check(x)
        fresh = StaciModel(cfg.inp_file);
        release_fresh = onCleanup(@()fresh.release());
        [metrics,violation] = wdn.evaluate_staci_design( ...
            fresh,cfg,x,link_order,original);
        clear release_fresh fresh
    end

    function f = fitness(x)
        calculate(x);
        f = last_f;
    end

    function [c,ceq] = constraints(x)
        calculate(x);
        c = last_c;
        ceq = [];
    end

    function calculate(x)
        x = double(x(:));
        if isequal(x,last_x),return;end
        try
            st.setLinkProperty(ids,'diameter_m',x*0.0254);
            status = st.solveHydraulics();
            assert(status.converged,'STACI hydraulics did not converge.');
            nodes = st.nodeResults();
            node_ids = string(nodes.id(:));
            pressure = double(nodes.pressure_head_m(:));
            [found,pi] = ismember(string(cfg.pressure_node_ids(:)),node_ids);
            assert(all(found),'A pressure node is missing.');
            c = [cfg.minimum_pressure + cfg.ga.pressure_numerical_guard_m ...
                - pressure(pi);pressure(pi) - ...
                (cfg.maximum_pressure - cfg.ga.pressure_numerical_guard_m)];
            [found,ai] = ismember( ...
                string(cfg.pressure_anchor_node_ids(:)),node_ids);
            assert(all(found),'A pressure-anchor node is missing.');
            anchor_ft = double(nodes.total_head_m(ai))/0.3048;
            c = [c;abs(anchor_ft(:) - ...
                cfg.pressure_anchor_target_heads(:)) - ...
                (cfg.pressure_anchor_head_tolerance - ...
                cfg.ga.anchor_numerical_guard_ft)];
            quality = st.solveSteadyQuality('chemical');
            chlorine_guard = 0;
            if isfield(cfg.ga,'chlorine_numerical_guard_mgL')
                chlorine_guard = cfg.ga.chlorine_numerical_guard_mgL;
            end
            chlorine = wdn.consumer_chlorine_constraint( ...
                nodes,quality,chlorine_guard);
            c = [c;chlorine(:)];
            f = -wdn.staci_todini_index(st,cfg);
        catch ME
            if evaluations == 0
                fprintf(2,'First SQP candidate error: %s\n',ME.message);
            end
            f = 1e6;
            c = 1e6*ones(2*numel(cfg.pressure_node_ids) + ...
                numel(cfg.pressure_anchor_node_ids) + ...
                numel(cfg.quality_node_ids),1);
        end
        last_x = x;
        last_f = f;
        last_c = c;
        evaluations = evaluations + 1;
    end
end

function path = relative_seed_path(seed_file,paper_root)
prefix = [char(paper_root),filesep];
path = char(seed_file);
if startsWith(path,prefix)
    path = path(numel(prefix)+1:end);
end
path = strrep(path,filesep,'/');
end
