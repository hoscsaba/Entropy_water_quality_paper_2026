function report = validate_environment(staci_root, mex_dir)
%VALIDATE_ENVIRONMENT Check the STACI checkout and archived final designs.
% This is a read-only preflight. The separate supplementary validator runs
% all 15 saved designs independently in EPANET.

root = fileparts(mfilename('fullpath'));
addpath(root);
if nargin >= 1 && ~isempty(staci_root)
    addpath(fullfile(staci_root, 'matlab'));
end
if nargin >= 2 && ~isempty(mex_dir)
    addpath(mex_dir);
end

report.matlab_release = string(version('-release'));
report.matlab_version = string(version);
report.has_global_optimization_toolbox = license('test', 'GADS_Toolbox');
report.has_optimization_toolbox = license('test', 'Optimization_Toolbox');
report.has_staci_mex = exist('staci_mex', 'file') == 3;
assert(report.has_global_optimization_toolbox && ...
       report.has_optimization_toolbox, ...
       'Both MATLAB optimization toolboxes are required.');
assert(report.has_staci_mex, ...
       'The STACI MATLAB MEX binary was not found on the path.');
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
    path_cleanup = onCleanup(@() rmpath(network_dir));
    clear network_config;
    cfg = network_config(network_dir);
    input_file = fullfile(network_dir, 'input', ...
        'network_staci_fixed_load.inp');
    objective_names = string(cfg.objectives);
    results_complete = true;
    for name = objective_names
        result_file = fullfile(network_dir, 'results_staci', name + ".mat");
        if ~isfile(result_file)
            results_complete = false;
            break;
        end
        saved = load(result_file, 'result');
        result = saved.result;
        valid = strcmp(string(result.network_id), string(cfg.id)) && ...
            numel(result.design_diameters) == numel(cfg.design_link_ids) && ...
            all(isfinite(result.design_diameters)) && ...
            result.max_constraint_violation <= cfg.ga.constraint_tolerance;
        results_complete = results_complete && valid;
    end
    report.networks(index, :) = {network_ids(index), ...
        numel(cfg.design_link_ids), isfile(input_file), results_complete};
    clear path_cleanup;
end

assert(all(report.networks.InputFound) && ...
       all(report.networks.ResultsComplete), ...
       'A STACI input or final saved design is missing or invalid.');
fprintf('MATLAB %s (%s); STACI MEX ready.\n', ...
    report.matlab_version, report.matlab_release);
disp(report.networks);
end
