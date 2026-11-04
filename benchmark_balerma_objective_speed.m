function results = benchmark_balerma_objective_speed
%BENCHMARK_BALERMA_OBJECTIVE_SPEED Measure complete chlorine fitness calls.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);
[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
designs = load_designs(cfg, model);
design_names = ["original","cost","hydraulic_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
objectives = {'chlorine_concentration','chlorine_entropy'};
repetitions = 5;
rows = table;

for design_index = 1:size(designs, 1)
    x = designs(design_index, :);
    for objective_index = 1:numel(objectives)
        objective = objectives{objective_index};
        for method = ["legacy","optimized"]
            timings = zeros(repetitions, 1);
            values = zeros(repetitions, 1);
            for repetition = 1:repetitions
                started = tic;
                if method == "legacy"
                    values(repetition) = legacy_objective( ...
                        x, d, cfg, model, objective);
                else
                    values(repetition) = wdn.objective_value( ...
                        x, d, cfg, model, objective);
                end
                timings(repetition) = toc(started);
            end
            row = table(design_index, design_names(design_index), ...
                string(objective), method, median(timings), min(timings), ...
                max(timings), values(end), ...
                'VariableNames', {'Design','DesignName','Objective','Method', ...
                'MedianSeconds','MinSeconds','MaxSeconds','Value'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end

rows.AbsoluteDifference = zeros(height(rows), 1);
rows.Speedup = nan(height(rows), 1);
for row_index = 1:height(rows)
    other = rows.Design == rows.Design(row_index) & ...
        rows.Objective == rows.Objective(row_index) & ...
        rows.Method ~= rows.Method(row_index);
    rows.AbsoluteDifference(row_index) = ...
        abs(rows.Value(row_index) - rows.Value(other));
    if rows.Method(row_index) == "optimized"
        rows.Speedup(row_index) = ...
            rows.MedianSeconds(other) / rows.MedianSeconds(row_index);
    end
end
results = rows;
save(fullfile(cfg.results_dir, 'benchmark_balerma_objective_speed.mat'), ...
    'results');
writetable(results, fullfile(cfg.results_dir, ...
    'benchmark_balerma_objective_speed.csv'));
disp(results);
end

function value = legacy_objective(x, d, cfg, model, objective)
wdn.apply_design(d, x, cfg, model);
d.solveCompleteHydraulics;
chlorine = legacy_chlorine(d, cfg);
if strcmp(objective, 'chlorine_concentration')
    value = -sum(chlorine(model.quality_node_indices).^2);
else
    value = -wdn.flow_entropy(d, model, chlorine);
end
end

function chlorine = legacy_chlorine(d, cfg)
d.setTimeSimulationDuration(cfg.quality_duration_hours * 3600);
d.setQualityType('chem', 'Chlorine');
d.setTimeQualityStep(cfg.quality_step_hours * 3600);
d.setTimeReportingStep(cfg.quality_step_hours * 3600);
for k = 1:double(d.getLinkCount)
    d.setLinkBulkReactionCoeff(k, cfg.bulk_reaction_coefficient);
end
node_ids = string(d.getNodeNameID);
[found, source_nodes] = ismember(string(cfg.source_node_ids), node_ids);
assert(all(found));
initial_quality = zeros(1, double(d.getNodeCount));
initial_quality(source_nodes) = cfg.source_chlorine;
d.setNodeInitialQuality(initial_quality);
for n = source_nodes(:)'
    d.setNodeSourceType(n, 'CONCEN');
    d.setNodeSourceQuality(n, cfg.source_chlorine);
end
series = d.getComputedQualityTimeSeries;
chlorine = double(series.NodeQuality(end, :)');
end

function designs = load_designs(cfg, model)
files = {'cost.mat','hydraulic_entropy.mat','chlorine_concentration.mat', ...
    'chlorine_entropy.mat','todini.mat'};
designs = zeros(numel(files) + 1, numel(cfg.design_link_ids));
designs(1, :) = model.original_full_diameters(model.design_link_indices);
for k = 1:numel(files)
    saved = load(fullfile(cfg.results_dir, files{k}), 'result');
    designs(k + 1, :) = saved.result.design_diameters;
end
end
