function run_anytown_ranking_study
%RUN_ANYTOWN_RANKING_STUDY Reproduce rankings and both Fig. 9 series.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end

ranking = wdn.rank_pipes(cfg);
save(fullfile(cfg.results_dir, 'pipe_rankings.mat'), 'ranking', 'cfg');
rank_count = 20;
rank_table = table((1:rank_count)', 'VariableNames', {'Rank'});
for q = 1:numel(ranking.criterion_keys)
    variable_name = matlab.lang.makeValidName(ranking.criterion_keys{q});
    rank_table.(variable_name) = string(ranking.ordered_link_ids(1:rank_count, q));
end
writetable(rank_table, fullfile(cfg.results_dir, 'pipe_rankings_top20.csv'));

cost_file = load(fullfile(cfg.results_dir, 'cost.mat'), 'result');
entropy_file = load(fullfile(cfg.results_dir, 'hydraulic_entropy.mat'), 'result');
cost_study = wdn.optimize_ranked_subsets(cfg, ranking, 'cost', ...
    cfg.ranking.k_values, cost_file.result);
ranking_cost_endpoint = wdn.refine_ranked_endpoint( ...
    cfg, cost_study, cost_file.result);
cost_study = replace_full_endpoint(cost_study, ranking_cost_endpoint);
save(fullfile(cfg.results_dir, 'ranking_full_cost.mat'), ...
    'ranking_cost_endpoint', 'cfg');
save(fullfile(cfg.results_dir, 'ranking_cost_study.mat'), ...
    'cost_study', 'ranking', 'ranking_cost_endpoint', 'cfg');
entropy_study = wdn.optimize_ranked_subsets(cfg, ranking, 'hydraulic_entropy', ...
    cfg.ranking.k_values, entropy_file.result);
ranking_entropy_endpoint = wdn.refine_ranked_endpoint( ...
    cfg, entropy_study, entropy_file.result);
entropy_study = replace_full_endpoint(entropy_study, ranking_entropy_endpoint);
save(fullfile(cfg.results_dir, 'ranking_full_hydraulic_entropy.mat'), ...
    'ranking_entropy_endpoint', 'cfg');
save(fullfile(cfg.results_dir, 'ranking_entropy_study.mat'), ...
    'entropy_study', 'ranking', 'ranking_entropy_endpoint', 'cfg');

all_results = cell(size(cfg.objectives));
for k = 1:numel(cfg.objectives)
    loaded = load(fullfile(cfg.results_dir, [cfg.objectives{k} '.mat']), 'result');
    all_results{k} = loaded.result;
end
all_results{1} = ranking_cost_endpoint;
all_results{2} = ranking_entropy_endpoint;
normalizers.cost = all_results{1}.metrics.cost;
for metric = {'hydraulic_entropy','chlorine_concentration','chlorine_entropy','todini'}
    values = cellfun(@(r) r.metrics.(metric{1}), all_results);
    normalizers.(metric{1}) = max(values);
end
save(fullfile(cfg.results_dir, 'ranking_dual_study.mat'), ...
    'cost_study', 'entropy_study', 'ranking', 'normalizers', 'cfg');
write_study_csv(cfg, cost_study, 'ranking_cost_study.csv');
write_study_csv(cfg, entropy_study, 'ranking_entropy_study.csv');

files = wdn.plot_ranking_objective_matrix( ...
    cfg, cost_study, entropy_study, normalizers);
draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~exist(draft_figures, 'dir'), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
fprintf('Dual ranking study and Fig. 9 written successfully.\n');
end

function study = replace_full_endpoint(study, endpoint)
last = find(study.k == 38, 1);
for q = 1:numel(study.criterion_keys)
    study.designs(q, last, :) = endpoint.design_diameters;
    for m = 1:numel(study.metric_names)
        study.metrics(q, last, m) = endpoint.metrics.(study.metric_names{m});
    end
    study.max_constraint_violations(q, last) = endpoint.max_constraint_violation;
    study.is_feasible(q, last) = true;
end
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
