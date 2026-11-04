function run_staci_chlorine_optimizations(staci_root, mex_dir, networks)
%RUN_STACI_CHLORINE_OPTIMIZATIONS Reproduce constrained steady-chlorine GAs.
% Example:
% run_staci_chlorine_optimizations('/path/to/staci', ...
%     '/path/to/staci/build/matlab', ...
%     {'tanyimboh_templeman','anytown','balerma'})

root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(staci_root, 'matlab'));
addpath(mex_dir);
if nargin < 3 || isempty(networks)
    networks = {'tanyimboh_templeman', 'anytown', 'balerma'};
end
for network = string(networks)
    network_dir = fullfile(root, 'networks', network);
    addpath(network_dir);
    cfg = network_config(network_dir);
    cfg.ga.display = 'final';
    if network == "anytown"
        % Preserved 100-generation STACI designs seeded the published
        % 200-generation continuation. Load once before any MEX solve;
        % candidate evaluation remains entirely in memory.
        seed_file = fullfile(network_dir, 'seeds', ...
            'staci_chlorine_100_generation_seeds.mat');
        seeds = load(seed_file, 'design_link_ids', 'seed_designs');
        assert(isequal(string(seeds.design_link_ids(:)), ...
            string(cfg.design_link_ids(:))), 'Anytown seed link order mismatch');
        cfg.ga.additional_seed_designs = seeds.seed_designs;
    end
    input_file = fullfile(network_dir, 'input', ...
        'network_staci_fixed_load.inp');
    result_dir = fullfile(network_dir, 'results_staci_constrained');
    if ~isfolder(result_dir), mkdir(result_dir); end
    for name = ["chlorine_concentration", "chlorine_entropy"]
        output_file = fullfile(result_dir, name + ".mat");
        wdn.optimize_staci_chlorine(cfg, char(name), input_file, output_file);
    end
end
end
