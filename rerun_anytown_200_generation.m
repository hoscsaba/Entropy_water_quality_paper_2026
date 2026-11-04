function rerun_anytown_200_generation(output_dir)
%RERUN_ANYTOWN_200_GENERATION Reproduce the five published 200-generation GAs.
% The compact 100-generation diameter archive is used only as GA warm starts.
% Results go to an isolated directory; published result MAT files are untouched.
root = fileparts(mfilename('fullpath'));
network_dir = fullfile(root, 'networks', 'anytown');
addpath(root, network_dir);
cfg = network_config(network_dir);
assert(cfg.ga.max_generations == 200 && cfg.ga.max_stall_generations == 100);
if nargin < 1 || strlength(string(output_dir)) == 0
    output_dir = fullfile(network_dir, 'reproduction_200');
end
output_dir = char(output_dir);
assert(~strcmp(output_dir, cfg.results_dir), ...
    'Use a separate output directory to preserve the published archive.');
if ~isfolder(output_dir), mkdir(output_dir); end
for name = string(cfg.objectives)
    assert(~isfile(fullfile(output_dir, name + ".mat")), ...
        'Output already contains an objective MAT: %s', name);
end
seeds = load(fullfile(network_dir, 'seeds', ...
    'epanet_100_generation_seeds.mat'));
assert(isequal(string(seeds.seed_objectives(:)), ...
    string(cfg.objectives(:))), 'Seed objective order mismatch');
assert(isequal(string(seeds.design_link_ids(:)), ...
    string(cfg.design_link_ids(:))), 'Seed link order mismatch');
assert(size(seeds.seed_designs, 1) == numel(cfg.objectives));
% optimize_single_objective reads only the diameter vector from compatible
% saved results while initializing its cross-objective elite population.
for k = 1:numel(cfg.objectives)
    result = struct('design_diameters', seeds.seed_designs(k, :));
    save(fullfile(output_dir, string(cfg.objectives{k}) + ".mat"), ...
        'result', '-v7');
end
cfg.results_dir = output_dir;
cfg.runtime_dir = fullfile(output_dir, 'runtime');
if ~isfolder(cfg.runtime_dir), mkdir(cfg.runtime_dir); end
wdn.setup_toolkit(cfg);
for name = string(cfg.objectives)
    fprintf('Anytown 200 generations: %s\n', name);
    result = wdn.optimize_single_objective(cfg, char(name));
    save(fullfile(cfg.results_dir, name + ".mat"), 'result', 'cfg', '-v7');
end
wdn.synchronize_objective_archive(cfg);
wdn.write_cross_evaluation(cfg);
end
