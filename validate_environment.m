function report = validate_environment
%VALIDATE_ENVIRONMENT Check a checkout without launching an optimization.

root = fileparts(mfilename('fullpath'));
addpath(root);

report.matlab_release = string(version('-release'));
report.matlab_version = string(version);
report.has_global_optimization_toolbox = license('test', 'GADS_Toolbox');
report.has_optimization_toolbox = license('test', 'Optimization_Toolbox');
if ~report.has_global_optimization_toolbox
    error('release:MissingToolbox', ...
        'Global Optimization Toolbox is required for article production runs.');
end
if report.matlab_release ~= "2026a"
    warning('release:MatlabVersion', ...
        'Article results used R2026a; this checkout is running %s.', ...
        report.matlab_release);
end

network_ids = ["tanyimboh_templeman", "anytown", "balerma"];
report.networks = table('Size', [numel(network_ids), 4], ...
    'VariableTypes', {'string','double','logical','logical'}, ...
    'VariableNames', {'Network','DesignLinks','InputFound','ResultsComplete'});
for index = 1:numel(network_ids)
    network_dir = fullfile(root, 'networks', char(network_ids(index)));
    addpath(network_dir);
    clear network_config;
    cfg = network_config(network_dir);
    path_cleanup = onCleanup(@() rmpath(network_dir));
    result_files = cellfun(@(name) isfile(fullfile(cfg.results_dir, ...
        [name '.mat'])), cfg.objectives);
    report.networks(index, :) = {network_ids(index), ...
        numel(cfg.design_link_ids), isfile(cfg.inp_file), all(result_files)};
    toolkit_override = string(getenv('WDS_EPANET_TOOLKIT'));
    toolkit_is_portable = startsWith(cfg.toolkit_dir, root) || ...
        (strlength(toolkit_override) > 0 && string(cfg.toolkit_dir) == toolkit_override);
    if ~toolkit_is_portable || ~startsWith(cfg.inp_file, root)
        error('release:NonPortablePath', ...
            'Configuration contains a machine-specific path: %s', network_ids(index));
    end
    if all(result_files)
        wdn.write_cross_evaluation(cfg);
    end
    clear path_cleanup;
end

fprintf('MATLAB %s (%s)\n', report.matlab_version, report.matlab_release);
disp(report.networks);
fprintf('Environment and stored cross-evaluations passed validation.\n');
end
