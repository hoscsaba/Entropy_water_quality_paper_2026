function run_balerma_ranking_study
%RUN_BALERMA_RANKING_STUDY Run or resume the cached Balerma ranking study.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

ranking_file = fullfile(cfg.results_dir, 'pipe_rankings.mat');
if isfile(ranking_file)
    saved = load(ranking_file, 'ranking');
    ranking = saved.ranking;
    fprintf('Loaded existing Balerma ranking.\n');
else
    ranking = wdn.rank_pipes(cfg);
    save(ranking_file, 'ranking', 'cfg');
end
write_top_rankings(cfg, ranking, 45);

cost_file = load(fullfile(cfg.results_dir, 'cost.mat'), 'result');
entropy_file = load(fullfile(cfg.results_dir, 'hydraulic_entropy.mat'), 'result');
cost_study = wdn.optimize_ranked_subsets(cfg, ranking, 'cost', ...
    cfg.ranking.k_values, cost_file.result);
save(fullfile(cfg.results_dir, 'ranking_cost_study.mat'), ...
    'cost_study', 'ranking', 'cfg');
write_study_csv(cfg, cost_study, 'ranking_cost_study.csv');

entropy_study = wdn.optimize_ranked_subsets(cfg, ranking, ...
    'hydraulic_entropy', cfg.ranking.k_values, entropy_file.result);
save(fullfile(cfg.results_dir, 'ranking_entropy_study.mat'), ...
    'entropy_study', 'ranking', 'cfg');
write_study_csv(cfg, entropy_study, 'ranking_entropy_study.csv');

normalizers = struct();
files = wdn.plot_ranking_objective_matrix( ...
    cfg, cost_study, entropy_study, normalizers);
draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(draft_figures), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
save(fullfile(cfg.results_dir, 'ranking_dual_study.mat'), ...
    'cost_study', 'entropy_study', 'ranking', 'normalizers', 'cfg');
fprintf('Balerma ranking study and combined objective matrix written.\n');
end

function write_top_rankings(cfg, ranking, rank_count)
rank_count = min(rank_count, size(ranking.ordered_link_ids, 1));
rank_table = table((1:rank_count)', 'VariableNames', {'Rank'});
for q = 1:numel(ranking.criterion_keys)
    variable_name = matlab.lang.makeValidName(ranking.criterion_keys{q});
    rank_table.(variable_name) = string(ranking.ordered_link_ids(1:rank_count, q));
end
writetable(rank_table, fullfile(cfg.results_dir, 'pipe_rankings_top45.csv'));
end

function write_study_csv(cfg, study, filename)
rows = table;
for q = 1:numel(study.criterion_keys)
    for j = 1:numel(study.k)
        row = table(string(study.criterion_keys{q}), study.k(j), ...
            study.metrics(q,j,1), study.metrics(q,j,2), study.metrics(q,j,3), ...
            study.metrics(q,j,4), study.metrics(q,j,5), ...
            study.is_feasible(q,j), study.max_constraint_violations(q,j), ...
            study.elapsed_seconds(q,j), ...
            'VariableNames', {'Criterion','K','Cost','HydraulicEntropy', ...
            'ChlorineConcentration','ChlorineEntropy','Todini', ...
            'IsFeasible','MaxConstraintViolation','ElapsedSeconds'});
        rows = [rows; row]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(cfg.results_dir, filename));
end
