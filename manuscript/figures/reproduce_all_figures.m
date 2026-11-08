function reproduce_all_figures(staci_root, mex_dir)
%REPRODUCE_ALL_FIGURES Rebuild every active computational manuscript figure.
% This routine uses saved STACI results and does not launch a GA.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root, '-begin');
addpath(fullfile(staci_root,'matlab'),mex_dir,'-begin');
addpath(fullfile(root, 'manuscript', 'figures'), '-begin');
addpath(fullfile(root, 'manuscript', 'tables'), '-begin');
addpath(fullfile(root, 'networks', 'anytown'), '-begin');
generated_dir = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(generated_dir), mkdir(generated_dir); end

make_pressure_anchor_mwe_figure;
make_two_consumer_entropy_example;
make_two_consumer_chlorine_entropy_example(false);
make_tanyimboh_reference_schematic;
make_tanyimboh_equal_entropy_pair;
% Supplementary S3 is a saved, independently checked inverse-sizing pair.
node6_dir=fullfile(root,'networks','tanyimboh_templeman', ...
    'experiments','node6_reservoir');
addpath(node6_dir,'-begin');
plot_node6_reservoir_pair;
copy_pair(fullfile(node6_dir,'node6_reservoir_equal_entropy_pair.png'), ...
    generated_dir);
make_figure3;
make_anytown_schematic;
make_anytown_anchor_replay_figures;
anytown_figures=fullfile(root,'networks','anytown', ...
    'figures_staci_anchor_replay');
copy_pair(fullfile(anytown_figures,'figure4.png'),generated_dir);
copy_pair(fullfile(anytown_figures,'figure5.png'),generated_dir);
make_balerma_schematic;
make_balerma_figures;
replot_anytown_anchor_rankings(root,generated_dir);

replot_cost_entropy(root, generated_dir);
replot_hydraulic_rankings(root, 'balerma', generated_dir);
replot_chlorine_rankings(root, 'balerma', generated_dir);
make_objective_relationship_summary(staci_root,mex_dir,'anchor_replay');

fprintf('All active computational manuscript figures are in %s\n', ...
    generated_dir);
end

function replot_cost_entropy(root, generated_dir)
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir, '-begin');
clear network_config
cfg = network_config_anchor_replay(network_dir);
saved = load(fullfile(cfg.results_dir, ...
    'pareto_plot_archive.mat'));
fields=fieldnames(saved);
output_file = fullfile(cfg.figures_dir, 'figure7_cost_entropy.png');
wdn.plot_cost_entropy_front(saved.(fields{1}), cfg, output_file);
copy_pair(output_file, generated_dir);
end

function replot_anytown_anchor_rankings(root, generated_dir)
network_dir=fullfile(root,'networks','anytown');
addpath(network_dir,'-begin');
clear network_config
cfg=network_config_anchor_replay(network_dir);
folder=cfg.results_dir;
a=load(fullfile(folder,'ranking_cost_study.mat'),'study');
b=load(fullfile(folder,'ranking_branch_hop_weighted_entropy_study.mat'),'study');
wdn.plot_ranking_objective_matrix(cfg,a.study,b.study,struct());
a=load(fullfile(folder,'ranking_chlorine_concentration_study.mat'),'study');
b=load(fullfile(folder,'ranking_chlorine_entropy_study.mat'),'study');
wdn.plot_ranking_chlorine_matrix(cfg,a.study,b.study);
copy_pair(fullfile(cfg.figures_dir,'figure9_ranking_objectives.png'), ...
    generated_dir);
copy_pair(fullfile(cfg.figures_dir, ...
    'figure10_anytown_chlorine_ranking_objectives.png'),generated_dir);
end

function replot_hydraulic_rankings(root, network_id, generated_dir)
network_dir = fullfile(root, 'networks', network_id);
cost=load(fullfile(network_dir,'results_staci','ranking_cost_study.mat'), ...
    'cost_study');
if isfile(fullfile(network_dir,'results_staci', ...
        'ranking_branch_hop_study.mat'))
    cost=load(fullfile(network_dir,'results_staci', ...
        'ranking_cost_branch_hop_study.mat'),'cost_branch_study');
    cost_study=cost.cost_branch_study;
else
    cost_study=cost.cost_study;
end
if isfile(fullfile(network_dir, ...
        'results_staci','ranking_branch_hop_study.mat'))
    entropy=load(fullfile(network_dir,'results_staci', ...
        'ranking_branch_hop_study.mat'),'branch_study');
    entropy_study=entropy.branch_study;
else
    entropy=load(fullfile(network_dir,'results_staci', ...
        'ranking_entropy_study.mat'),'entropy_study');
    entropy_study=entropy.entropy_study;
end
addpath(network_dir, '-begin');
clear network_config
cfg = network_config(network_dir);
cfg.results_dir = fullfile(network_dir, 'results_staci');
cfg.figures_dir = fullfile(network_dir, 'figures_staci');
files = wdn.plot_ranking_objective_matrix(cfg, cost_study, ...
    entropy_study, struct());
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
clear network_config
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
