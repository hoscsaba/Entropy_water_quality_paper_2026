function report = validate_environment(staci_root, mex_dir)
%VALIDATE_ENVIRONMENT Check software, fixed-load inputs and 18 final designs.
% Read-only preflight: no optimization, hydraulic solve or EPANET run.
root = fileparts(mfilename('fullpath'));
addpath(root);
if nargin >= 1 && ~isempty(staci_root)
    addpath(fullfile(staci_root,'matlab'));
end
if nargin >= 2 && ~isempty(mex_dir)
    addpath(mex_dir);
end
report.matlab_release = string(version('-release'));
report.matlab_version = string(version);
report.has_global_optimization_toolbox = license('test','GADS_Toolbox');
report.has_optimization_toolbox = license('test','Optimization_Toolbox');
report.has_staci_mex = exist('staci_mex','file') == 3;
assert(report.has_global_optimization_toolbox && ...
    report.has_optimization_toolbox,'Both optimization toolboxes are required.');
assert(report.has_staci_mex,'Build staci_mex and add its directory to the path.');
if report.matlab_release ~= "2026a"
    warning('release:MatlabVersion', ...
        'Published calculations used R2026a; this is %s.',report.matlab_release);
end
ids = ["tanyimboh_templeman","anytown","balerma"];
report.networks = table('Size',[numel(ids),5], ...
    'VariableTypes',{'string','double','double','logical','logical'}, ...
    'VariableNames',{'Network','DesignLinks','FinalDesigns','InputFound','ResultsComplete'});
for k = 1:numel(ids)
    network_dir = fullfile(root,'networks',char(ids(k)));
    addpath(network_dir,'-begin');
    clear network_config
    switch ids(k)
        case "tanyimboh_templeman"
            cfg=network_config(network_dir);
            results_dir=fullfile(network_dir, ...
                'results_staci_10_120_clsplit_v2');
            input_file=fullfile(network_dir,'input', ...
                'network_staci_fixed_load.inp');
        case "anytown"
            cfg=network_config_anchor_replay(network_dir);
            results_dir=fullfile(network_dir,'results_staci_anchor_replay');
            input_file=fullfile(network_dir,'input', ...
                'network_anchor_replay.inp');
        case "balerma"
            cfg=network_config_r38_anchor(network_dir);
            results_dir=fullfile(network_dir, ...
                'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
            input_file=fullfile(network_dir,'input', ...
                'network_r38_anchor_fixed_load.inp');
    end
    names=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
        "chlorine_concentration","chlorine_entropy","todini"];
    complete = true;
    for name = names
        result_file = fullfile(results_dir,char(name)+".mat");
        if ~isfile(result_file), complete = false; break; end
        saved = load(result_file,'result');
        result = saved.result;
        complete = complete && strcmp(string(result.network_id),string(cfg.id)) && ...
            numel(result.design_diameters) == numel(cfg.design_link_ids) && ...
            all(isfinite(result.design_diameters)) && ...
            result.max_constraint_violation <= cfg.ga.constraint_tolerance;
    end
    report.networks(k,:) = {ids(k),numel(cfg.design_link_ids), ...
        numel(names),isfile(input_file),complete};
    rmpath(network_dir);
end
assert(all(report.networks.InputFound) && all(report.networks.ResultsComplete), ...
    'A fixed-load input or full-precision final design is missing or invalid.');
report.has_balerma_rankings = isfile(fullfile(root,'networks','balerma', ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1', ...
    'ranking_branch_hop_study.mat'));
assert(report.has_balerma_rankings, ...
    'The released Balerma R38-anchor ranking archive is missing.');
fprintf('MATLAB %s (%s); STACI MEX ready.\n', ...
    report.matlab_version,report.matlab_release);
disp(report.networks);
end
