function run_staci_outage_studies(staci_root, mex_dir, networks, result_dir_override)
%RUN_STACI_OUTAGE_STUDIES DDA stress and PDA service of saved STACI optima.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(staci_root, 'matlab'), mex_dir);
if nargin < 3 || isempty(networks), networks = {'anytown','balerma'}; end
labels = ["Cost", "Hydraulic entropy", "Chlorine concentration", ...
    "Chlorine entropy", "Todini"];
for network = string(networks)
    network_dir = char(fullfile(root, 'networks', network));
    addpath(network_dir);
    cfg = network_config(network_dir);
    if nargin>=4 && ~isempty(result_dir_override)
        cfg.results_dir=char(result_dir_override);
    end
    input_file = fullfile(network_dir, 'input', 'network_staci_fixed_load.inp');
    result_dir = cfg.results_dir;
    pda_file = fullfile(result_dir, 'runtime', 'network_pda_fixed_load.inp');
    wdn.write_staci_pda_input(cfg, input_file, pda_file);
    stress_summaries = cell(5,1);
    stress_scenarios = cell(5,1);
    pda_summaries = cell(5,1);
    pda_scenarios = cell(5,1);
    design_vectors = cell(5,1);
    for k = 1:5
        result = load(fullfile(result_dir, string(cfg.objectives{k}) + ".mat"), ...
            'result');
        x = result.result.design_diameters;
        prior = find(cellfun(@(v) ~isempty(v) && isequal(v,x), ...
            design_vectors(1:k-1)),1);
        if ~isempty(prior)
            fprintf('STACI outage replay %s/%s: reuse identical %s vector\n', ...
                network,labels(k),labels(prior));
            stress_summaries{k} = stress_summaries{prior};
            stress_summaries{k}.topology = labels(k);
            stress_scenarios{k} = stress_scenarios{prior};
            stress_scenarios{k}.Topology(:) = labels(k);
            pda_summaries{k} = pda_summaries{prior};
            pda_summaries{k}.Topology(:) = labels(k);
            pda_scenarios{k} = pda_scenarios{prior};
            pda_scenarios{k}.Topology(:) = labels(k);
        else
            fprintf('STACI outage replay %s/%s\n', network, labels(k));
            [stress_summaries{k}, stress_scenarios{k}] = ...
                wdn.staci_pipe_failure_stress_test(cfg, x, labels(k), input_file);
            [pda_summaries{k}, pda_scenarios{k}] = ...
                wdn.staci_pda_failure_service(cfg, x, labels(k), ...
                input_file, pda_file);
        end
        design_vectors{k} = x;
        summary_struct = vertcat(stress_summaries{1:k});
        summary_table = struct2table(summary_struct);
        scenario_table = vertcat(stress_scenarios{1:k});
        save(fullfile(result_dir, 'stress_test.mat'), ...
            'summary_struct', 'summary_table', 'scenario_table', 'cfg');
        writetable(summary_table, fullfile(result_dir, 'stress_test.csv'));
        writetable(scenario_table, fullfile(result_dir, 'stress_test_scenarios.csv'));
        pda_summary = vertcat(pda_summaries{1:k});
        pda_detail = vertcat(pda_scenarios{1:k});
        writetable(pda_summary, fullfile(result_dir, 'pda_service_summary.csv'));
        writetable(pda_detail, fullfile(result_dir, 'pda_service_scenarios.csv'));
        save(fullfile(result_dir, 'pda_service_results.mat'), ...
            'pda_summary', 'pda_detail', 'cfg');
    end
    rmpath(network_dir);
end
end
