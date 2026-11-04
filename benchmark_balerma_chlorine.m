function results = benchmark_balerma_chlorine
%BENCHMARK_BALERMA_CHLORINE Validate terminal quality and time-step changes.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

designs = load_designs(cfg);
design_names = ["original","cost","hydraulic_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
methods = {'legacy_timeseries','configured_terminal'};
hydraulic_steps = [1, 48];
repetitions = 3;
rows = table;

for h = hydraulic_steps
    [d, model] = wdn.open_network(cfg);
    cleanup = onCleanup(@() d.unload);
    trial_cfg = cfg;
    trial_cfg.quality_step_hours = h;
    d.setTimePatternStep(h * 3600);
    d.setTimeHydraulicStep(h * 3600);
    wdn.configure_chlorine(d, trial_cfg);
    actual_h = double(d.getTimeHydraulicStep) / 3600;
    actual_q = double(d.getTimeQualityStep) / 3600;
    fprintf('Requested Hstep=%g h, Qstep=%g h; actual Hstep=%g h, Qstep=%g h.\n', ...
        h, h, actual_h, actual_q);
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
                if strcmp(method, 'legacy_timeseries')
                    chlorine = legacy_quality(d, trial_cfg);
                else
                    chlorine = wdn.chlorine_state(d, trial_cfg);
                end
                timings(repetition) = toc(started);
            end
            row = table(h, actual_h, actual_q, design_index, ...
                design_names(design_index), string(method), median(timings), ...
                min(timings), max(timings), {chlorine}, ...
                'VariableNames', {'RequestedStepHours','ActualHydraulicStepHours', ...
                'ActualQualityStepHours','Design','DesignName','Method', ...
                'MedianSeconds','MinSeconds','MaxSeconds','Chlorine'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end
    clear cleanup d
end

rows.MaxAbsDifferenceFromReference = nan(height(rows), 1);
for row_index = 1:height(rows)
    reference_row = rows.RequestedStepHours == 1 & ...
        rows.Design == rows.Design(row_index) & ...
        rows.Method == "legacy_timeseries";
    reference = rows.Chlorine{reference_row};
    rows.MaxAbsDifferenceFromReference(row_index) = ...
        max(abs(rows.Chlorine{row_index} - reference));
end
results = rows;
save(fullfile(cfg.results_dir, 'benchmark_balerma_chlorine.mat'), 'results');
writetable(removevars(rows, 'Chlorine'), ...
    fullfile(cfg.results_dir, 'benchmark_balerma_chlorine.csv'));
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

function chlorine = legacy_quality(d, cfg)
% Exact pre-optimization implementation retained for regression testing.
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
