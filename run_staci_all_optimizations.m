function run_staci_all_optimizations(staci_root, mex_dir, networks, objectives, rerun_existing)
%RUN_STACI_ALL_OPTIMIZATIONS Reproduce five single-objective STACI designs.
% Candidate evaluations use the resident STACI MEX model and no file I/O.
% Each completed MAT is reusable as a seed; interrupted batches resume by
% skipping existing output files. A two-hour per-objective wall limit guards
% against unexpectedly long searches, and is reported with GA exit status.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(staci_root, 'matlab'), mex_dir);
if nargin < 3 || isempty(networks)
    networks = {'tanyimboh_templeman','anytown','balerma'};
end
if nargin < 4 || isempty(objectives)
    objectives = {'cost','hydraulic_entropy','chlorine_concentration', ...
        'chlorine_entropy','todini'};
end
if nargin < 5, rerun_existing = false; end
for network = string(networks)
    network_dir = char(fullfile(root, 'networks', network));
    addpath(network_dir);
    cfg = network_config(network_dir);
    cfg.ga.display = 'final';
    cfg.ga.max_generations = 10000;
    cfg.ga.max_stall_generations = max(150, cfg.ga.max_stall_generations);
    cfg.ga.maximum_wall_seconds = 7200;
    cfg.ga.use_hybrid_patternsearch = false;
    input_file = fullfile(network_dir, 'input', 'network_staci_fixed_load.inp');
    output_dir = fullfile(network_dir, 'results_staci');
    if ~isfolder(output_dir), mkdir(output_dir); end
    cfg.results_dir = output_dir;
    if network == "anytown"
        % The EPANET 2.2 replay differs from the double-precision STACI
        % anchor head by up to ~0.0001 ft at an active 0.5-ft boundary.
        % Leave a negligible 0.00025-ft interior margin for cross-engine
        % feasibility without changing the published 0.5-ft requirement.
        cfg.ga.anchor_numerical_guard_ft = 0.00025;
        seeds = load(fullfile(network_dir, 'seeds', ...
            'staci_chlorine_100_generation_seeds.mat'), ...
            'design_link_ids', 'seed_designs');
        assert(isequal(string(seeds.design_link_ids(:)), ...
            string(cfg.design_link_ids(:))), 'Anytown seed order mismatch');
        cfg.ga.additional_seed_designs = seeds.seed_designs;
        for objective_name = ["cost", "hydraulic_entropy"]
            endpoint_file = fullfile(cfg.results_dir, ...
                "ranking_full_" + objective_name + ".mat");
            if ~isfile(endpoint_file), continue; end
            endpoint = load(endpoint_file);
            if objective_name == "cost"
                design = endpoint.ranking_cost_endpoint.design_diameters;
            else
                design = endpoint.ranking_entropy_endpoint.design_diameters;
            end
            cfg.ga.additional_seed_designs(end + 1, :) = design(:)';
        end
        for objective_name = ["cost", "hydraulic_entropy", ...
                "chlorine_concentration", "chlorine_entropy"]
            cache_dir = fullfile(cfg.results_dir, 'ranking_cache', ...
                objective_name);
            for count = [35, 38]
                files = dir(fullfile(cache_dir, '*', ...
                    sprintf('k_%03d.mat', count)));
                for k = 1:numel(files)
                    item = load(fullfile(files(k).folder, files(k).name), ...
                        'entry');
                    if item.entry.is_feasible
                        cfg.ga.additional_seed_designs(end + 1, :) = ...
                            item.entry.design_diameters(:)';
                    end
                end
            end
        end
    end
    for objective = string(objectives)
        assert(ismember(objective, string(cfg.objectives)), ...
            'Unknown objective: %s', objective);
        output_file = fullfile(output_dir, objective + ".mat");
        if isfile(output_file) && ~rerun_existing
            fprintf('SKIP %s/%s: existing result\n', network, objective);
            continue;
        end
        fprintf('START %s/%s at %s\n', network, objective, datetime('now'));
        wdn.optimize_staci_single_objective(cfg, char(objective), ...
            input_file, output_file);
    end
    rmpath(network_dir);
end
end
