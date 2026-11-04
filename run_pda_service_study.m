function run_pda_service_study
%RUN_PDA_SERVICE_STUDY Re-evaluate saved designs without optimization.
root = fileparts(mfilename('fullpath'));
addpath(root);
network_names = {'anytown','balerma'};
labels = ["Cost", "Hydraulic entropy", "Chlorine concentration", ...
    "Chlorine entropy", "Todini"];
for a = 1:numel(network_names)
    network_dir = fullfile(root,'networks',network_names{a});
    addpath(network_dir);
    cfg = network_config(network_dir);
    wdn.setup_toolkit(cfg);
    all_designs = cell(numel(cfg.objectives),1);
    for k = 1:numel(cfg.objectives)
        saved = load(fullfile(cfg.results_dir, [cfg.objectives{k} '.mat']), 'result');
        all_designs{k} = saved.result.design_diameters;
    end
    summaries = cell(numel(cfg.objectives),1);
    details = cell(numel(cfg.objectives),1);
    for k = 1:numel(cfg.objectives)
        prior = 0;
        for j = 1:k-1
            if isequal(all_designs{k},all_designs{j}), prior = j; break; end
        end
        if prior > 0
            summaries{k} = summaries{prior};
            details{k} = details{prior};
            summaries{k}.Topology(:) = labels(k);
            details{k}.Topology(:) = labels(k);
            fprintf('%s / %s reuses the identical %s design.\n', ...
                cfg.id, labels(k), labels(prior));
        else
            fprintf('PDA service replay: %s / %s\n', cfg.id, labels(k));
            [summaries{k}, details{k}] = wdn.pda_failure_service( ...
                cfg, all_designs{k}, labels(k));
        end
        summary = vertcat(summaries{1:k});
        scenarios = vertcat(details{1:k});
        writetable(summary,fullfile(cfg.results_dir,'pda_service_summary.csv'));
        writetable(scenarios,fullfile(cfg.results_dir,'pda_service_scenarios.csv'));
        save(fullfile(cfg.results_dir,'pda_service_results.mat'), ...
            'summary','scenarios','cfg');
        disp(summaries{k});
    end
    rmpath(network_dir);
end
end
