function run_chlorine_ranking_study(network_id)
%RUN_CHLORINE_RANKING_STUDY Run or resume both chlorine ranking searches.
% Example: run_chlorine_ranking_study('anytown')

arguments
    network_id (1,1) string {mustBeMember(network_id,["anytown","balerma"])}
end

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', char(network_id));
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

ranking_file = fullfile(cfg.results_dir, 'pipe_rankings.mat');
if isfile(ranking_file)
    saved = load(ranking_file, 'ranking');
    ranking = saved.ranking;
else
    ranking = wdn.rank_pipes(cfg);
    save(ranking_file, 'ranking', 'cfg');
end

concentration_result = load( ...
    fullfile(cfg.results_dir, 'chlorine_concentration.mat'), 'result');
concentration_study = wdn.optimize_ranked_subsets(cfg, ranking, ...
    'chlorine_concentration', cfg.ranking.k_values, ...
    concentration_result.result);
save(fullfile(cfg.results_dir, ...
    'ranking_chlorine_concentration_study.mat'), ...
    'concentration_study', 'ranking', 'cfg');
wdn.write_ranking_study_csv(cfg, concentration_study, ...
    'ranking_chlorine_concentration_study.csv');

entropy_result = load( ...
    fullfile(cfg.results_dir, 'chlorine_entropy.mat'), 'result');
entropy_study = wdn.optimize_ranked_subsets(cfg, ranking, ...
    'chlorine_entropy', cfg.ranking.k_values, entropy_result.result);
save(fullfile(cfg.results_dir, 'ranking_chlorine_entropy_study.mat'), ...
    'entropy_study', 'ranking', 'cfg');
wdn.write_ranking_study_csv(cfg, entropy_study, ...
    'ranking_chlorine_entropy_study.csv');

files = wdn.plot_ranking_chlorine_matrix( ...
    cfg, concentration_study, entropy_study);
draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~exist(draft_figures, 'dir'), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
save(fullfile(cfg.results_dir, 'ranking_chlorine_dual_study.mat'), ...
    'concentration_study', 'entropy_study', 'ranking', 'cfg');
fprintf('%s chlorine ranking study and objective matrix written.\n', ...
    char(network_id));
end
