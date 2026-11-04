function finalize_anytown_ranking_study
%FINALIZE_ANYTOWN_RANKING_STUDY Refine K=38 endpoints without rerunning subsets.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);
cost_saved = load(fullfile(cfg.results_dir, 'ranking_cost_study.mat'), ...
    'cost_study', 'ranking');
entropy_saved = load(fullfile(cfg.results_dir, 'ranking_entropy_study.mat'), ...
    'entropy_study', 'ranking');
cost_previous = load(fullfile(cfg.results_dir, 'cost.mat'), 'result');
entropy_previous = load(fullfile(cfg.results_dir, 'hydraulic_entropy.mat'), 'result');

cost_study = cost_saved.cost_study;
entropy_study = entropy_saved.entropy_study;
ranking = cost_saved.ranking;
ranking_cost_endpoint = wdn.refine_ranked_endpoint( ...
    cfg, cost_study, cost_previous.result);
ranking_entropy_endpoint = wdn.refine_ranked_endpoint( ...
    cfg, entropy_study, entropy_previous.result);
cost_study = replace_endpoint(cost_study, ranking_cost_endpoint);
entropy_study = replace_endpoint(entropy_study, ranking_entropy_endpoint);
save(fullfile(cfg.results_dir, 'ranking_full_cost.mat'), ...
    'ranking_cost_endpoint', 'cfg');
save(fullfile(cfg.results_dir, 'ranking_full_hydraulic_entropy.mat'), ...
    'ranking_entropy_endpoint', 'cfg');
save(fullfile(cfg.results_dir, 'ranking_cost_study.mat'), ...
    'cost_study', 'ranking', 'ranking_cost_endpoint', 'cfg');
save(fullfile(cfg.results_dir, 'ranking_entropy_study.mat'), ...
    'entropy_study', 'ranking', 'ranking_entropy_endpoint', 'cfg');

all_results = cell(size(cfg.objectives));
for k = 1:numel(cfg.objectives)
    loaded = load(fullfile(cfg.results_dir, [cfg.objectives{k} '.mat']), 'result');
    all_results{k} = loaded.result;
end
all_results{1} = ranking_cost_endpoint;
all_results{2} = ranking_entropy_endpoint;
normalizers.cost = ranking_cost_endpoint.metrics.cost;
for metric = {'hydraulic_entropy','chlorine_concentration','chlorine_entropy','todini'}
    values = cellfun(@(r) r.metrics.(metric{1}), all_results);
    normalizers.(metric{1}) = max(values);
end
save(fullfile(cfg.results_dir, 'ranking_dual_study.mat'), ...
    'cost_study', 'entropy_study', 'ranking', 'normalizers', 'cfg');
write_csv(cfg, cost_study, 'ranking_cost_study.csv');
write_csv(cfg, entropy_study, 'ranking_entropy_study.csv');
files = wdn.plot_ranking_objective_matrix( ...
    cfg, cost_study, entropy_study, normalizers);
draft_figures = fullfile(root, 'manuscript', 'generated', 'figures');
if ~isfolder(draft_figures), mkdir(draft_figures); end
for k = 1:numel(files)
    [~, name, extension] = fileparts(files{k});
    copyfile(files{k}, fullfile(draft_figures, [name extension]), 'f');
end
end

function study = replace_endpoint(study, endpoint)
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

function write_csv(cfg, study, filename)
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
