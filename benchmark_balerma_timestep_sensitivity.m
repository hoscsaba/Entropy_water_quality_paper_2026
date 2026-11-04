function results = benchmark_balerma_timestep_sensitivity
%BENCHMARK_BALERMA_TIMESTEP_SENSITIVITY Test coarser EPANET time steps.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'balerma');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);
designs = load_designs(cfg);
design_names = ["original","cost","hydraulic_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
steps = [1, 2, 3, 6, 12, 24, 48];
rows = table;

for step = steps
    [d, model] = wdn.open_network(cfg);
    cleanup = onCleanup(@() d.unload);
    trial_cfg = cfg;
    trial_cfg.quality_step_hours = step;
    d.setTimePatternStep(step * 3600);
    d.setTimeHydraulicStep(step * 3600);
    wdn.configure_chlorine(d, trial_cfg);
    actual_h = double(d.getTimeHydraulicStep) / 3600;
    actual_q = double(d.getTimeQualityStep) / 3600;
    for design_index = 1:size(designs, 1)
        x = designs(design_index, :);
        wdn.apply_design(d, x, cfg, model);
        d.solveCompleteHydraulics;
        started = tic;
        chlorine = wdn.chlorine_state(d, trial_cfg);
        elapsed = toc(started);
        concentration = sum(chlorine(model.quality_node_indices).^2);
        entropy = wdn.flow_entropy(d, model, chlorine);
        row = table(step, actual_h, actual_q, design_index, ...
            design_names(design_index), elapsed, concentration, entropy, ...
            {chlorine}, 'VariableNames', {'RequestedStepHours', ...
            'ActualHydraulicStepHours','ActualQualityStepHours','Design', ...
            'DesignName','QualitySeconds','ChlorineConcentration', ...
            'ChlorineEntropy','Chlorine'});
        rows = [rows; row]; %#ok<AGROW>
    end
    clear cleanup d
end

rows.MaxAbsChlorineDifference = zeros(height(rows), 1);
rows.RelativeConcentrationDifference = zeros(height(rows), 1);
rows.RelativeEntropyDifference = zeros(height(rows), 1);
for row_index = 1:height(rows)
    reference_row = rows.RequestedStepHours == 1 & ...
        rows.Design == rows.Design(row_index);
    reference_chlorine = rows.Chlorine{reference_row};
    rows.MaxAbsChlorineDifference(row_index) = ...
        max(abs(rows.Chlorine{row_index} - reference_chlorine));
    rows.RelativeConcentrationDifference(row_index) = abs( ...
        rows.ChlorineConcentration(row_index) - ...
        rows.ChlorineConcentration(reference_row)) / ...
        abs(rows.ChlorineConcentration(reference_row));
    rows.RelativeEntropyDifference(row_index) = abs( ...
        rows.ChlorineEntropy(row_index) - rows.ChlorineEntropy(reference_row)) / ...
        abs(rows.ChlorineEntropy(reference_row));
end
results = rows;
save(fullfile(cfg.results_dir, ...
    'benchmark_balerma_timestep_sensitivity.mat'), 'results');
writetable(removevars(rows, 'Chlorine'), fullfile(cfg.results_dir, ...
    'benchmark_balerma_timestep_sensitivity.csv'));
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
