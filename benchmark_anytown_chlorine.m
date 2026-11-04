function results = benchmark_anytown_chlorine
%BENCHMARK_ANYTOWN_CHLORINE Compare terminal-quality evaluation strategies.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'anytown');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

designs = load_designs(cfg);
methods = {'legacy_timeseries','configured_timeseries', ...
    'configured_terminal','configured_solve_complete'};
hydraulic_steps = [3, 48];
repetitions = 5;
rows = table;

for h = hydraulic_steps
    [d, model] = wdn.open_network(cfg);
    cleanup = onCleanup(@() d.unload);
    d.setTimePatternStep(h * 3600);
    d.setTimeHydraulicStep(h * 3600);
    d.setTimeQualityStep(h * 3600);
    configure_quality(d, cfg);
    fprintf('Requested Hstep=%g h; actual Hstep=%g h, Qstep=%g h.\n', ...
        h, double(d.getTimeHydraulicStep)/3600, ...
        double(d.getTimeQualityStep)/3600);
    for design_index = 1:size(designs, 1)
        x = designs(design_index, :);
        wdn.apply_design(d, x, cfg, model);
        d.solveCompleteHydraulics;
        for method_index = 1:numel(methods)
            method = methods{method_index};
            timings = zeros(repetitions, 1);
            chlorine = [];
            for repetition = 1:repetitions
                started = tic;
                switch method
                    case 'legacy_timeseries'
                        chlorine = legacy_quality(d, cfg);
                    case 'configured_timeseries'
                        series = d.getComputedQualityTimeSeries;
                        chlorine = double(series.NodeQuality(end, :)');
                    case 'configured_terminal'
                        chlorine = terminal_quality(d);
                    case 'configured_solve_complete'
                        d.solveCompleteQuality;
                        quality_raw = d.getNodeActualQuality;
                        chlorine = double(quality_raw(:));
                end
                timings(repetition) = toc(started);
            end
            row = table(h, design_index, string(method), median(timings), ...
                min(timings), max(timings), {chlorine}, ...
                'VariableNames', {'HydraulicStepHours','Design','Method', ...
                'MedianSeconds','MinSeconds','MaxSeconds','Chlorine'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end
    clear cleanup d
end

rows.MaxAbsDifferenceFromReference = nan(height(rows), 1);
for row_index = 1:height(rows)
    same_design_reference = rows.HydraulicStepHours == 3 & ...
        rows.Design == rows.Design(row_index) & ...
        rows.Method == "legacy_timeseries";
    reference = rows.Chlorine{same_design_reference};
    rows.MaxAbsDifferenceFromReference(row_index) = ...
        max(abs(rows.Chlorine{row_index} - reference));
end
results = rows;
save(fullfile(cfg.results_dir, 'benchmark_anytown_chlorine.mat'), 'results');
writetable(removevars(rows, 'Chlorine'), ...
    fullfile(cfg.results_dir, 'benchmark_anytown_chlorine.csv'));
disp(removevars(rows, 'Chlorine'));
end

function designs = load_designs(cfg)
files = {'cost.mat','hydraulic_entropy.mat','chlorine_concentration.mat', ...
    'chlorine_entropy.mat','todini.mat'};
designs = zeros(numel(files) + 1, numel(cfg.design_link_ids));
[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
designs(1, :) = model.original_full_diameters(model.design_link_indices);
for k = 1:numel(files)
    saved = load(fullfile(cfg.results_dir, files{k}), 'result');
    designs(k + 1, :) = saved.result.design_diameters;
end
end

function configure_quality(d, cfg)
d.setTimeSimulationDuration(cfg.quality_duration_hours * 3600);
d.setQualityType('chem', 'Chlorine');
d.setTimeQualityStep(cfg.quality_step_hours * 3600);
d.setTimeReportingStep(cfg.quality_duration_hours * 3600);
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
end

function chlorine = terminal_quality(d)
d.openQualityAnalysis;
d.initializeQualityAnalysis;
time_left = 1;
time = 0;
duration = double(d.getTimeSimulationDuration);
while time_left > 0 || time < duration
    time = double(d.runQualityAnalysis);
    quality_raw = d.getNodeActualQuality;
    chlorine = double(quality_raw(:));
    time_left = double(d.stepQualityAnalysisTimeLeft);
end
d.closeQualityAnalysis;
end

function chlorine = legacy_quality(d, cfg)
% Exact pre-optimization implementation retained for regression benchmarking.
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
