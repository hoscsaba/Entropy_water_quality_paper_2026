function reproduce_all_figures(staci_root, mex_dir)
%REPRODUCE_ALL_FIGURES Rebuild every active computational manuscript figure.
% This routine uses saved STACI results and does not launch a GA.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root, '-begin');
addpath(fullfile(staci_root,'matlab'),mex_dir,'-begin');
addpath(fullfile(root, 'manuscript', 'figures'), '-begin');
addpath(fullfile(root, 'manuscript', 'tables'), '-begin');
generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end

make_pressure_anchor_mwe_figure;
make_two_consumer_entropy_example;
make_two_consumer_chlorine_entropy_example(false);
make_tanyimboh_reference_schematic;
make_figure3;
make_anytown_schematic;
make_anytown_figures;
make_balerma_schematic;
make_balerma_figures;
regenerate_anytown_ranking_figure;

replot_cost_entropy(root, generated_dir);
replot_chlorine_rankings(root, 'anytown', generated_dir);
replot_hydraulic_rankings(root, 'balerma', generated_dir);
replot_chlorine_rankings(root, 'balerma', generated_dir);
make_objective_relationship_summary(staci_root,mex_dir);

fprintf('All active computational manuscript figures are in %s\n', ...
    generated_dir);
end

function replot_cost_entropy(root, generated_dir)
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir, '-begin');
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir,'results_staci');
saved = load(fullfile(cfg.results_dir, ...
    'multiobjective_cost_entropy.mat'), 'result');
output_file = fullfile(cfg.figures_dir, 'figure7_cost_entropy.png');
wdn.plot_cost_entropy_front(saved.result, cfg, output_file);
copy_pair(output_file, generated_dir);
end

function replot_hydraulic_rankings(root, network_id, generated_dir)
network_dir = fullfile(root, 'networks', network_id);
cost=load(fullfile(network_dir,'results_staci','ranking_cost_study.mat'), ...
    'cost_study');
entropy=load(fullfile(network_dir,'results_staci', ...
    'ranking_entropy_study.mat'),'entropy_study');
addpath(network_dir, '-begin');
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir, 'results_staci');
cfg.figures_dir = fullfile(network_dir, 'figures_staci');
files = wdn.plot_ranking_objective_matrix(cfg, cost.cost_study, ...
    entropy.entropy_study, struct());
copy_files(files, generated_dir);
end

function replot_chlorine_rankings(root, network_id, generated_dir)
network_dir = fullfile(root, 'networks', network_id);
concentration=load(fullfile(network_dir,'results_staci', ...
    'ranking_chlorine_concentration_study.mat'), ...
    'concentration_study');
entropy=load(fullfile(network_dir,'results_staci', ...
    'ranking_chlorine_entropy_study.mat'),'entropy_study');
addpath(network_dir, '-begin');
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir, 'results_staci');
cfg.figures_dir = fullfile(network_dir, 'figures_staci');
files = wdn.plot_ranking_chlorine_matrix(cfg, ...
    concentration.concentration_study, entropy.entropy_study);
copy_files(files, generated_dir);
end

function copy_pair(png_file, generated_dir)
files = {png_file, replace(png_file, '.png', '.svg')};
copy_files(files, generated_dir);
end

function copy_files(files, generated_dir)
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(generated_dir, [name extension]), 'f');
end
end
