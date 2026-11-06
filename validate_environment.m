function report = validate_environment(staci_root, mex_dir)
%VALIDATE_ENVIRONMENT Check tools, inputs, and the 16 archived full-network designs.
% Read-only preflight: no optimizer or EPANET run is performed. The restricted
% 45-pipe Balerma design is a separate ranked-subset result.
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
    cfg = network_config(network_dir);
    names = string(cfg.objectives);
    if ids(k) == "anytown"
        names(end+1) = "branch_hop_weighted_entropy";
        results_dir = fullfile(network_dir,'results_staci_anchor_replay');
        input_file = fullfile(network_dir,'input','network_anchor_replay.inp');
    else
        results_dir = fullfile(network_dir,'results_staci');
        input_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');
    end
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
report.has_balerma_rank45_design = isfile(fullfile(root, ...
    'networks','balerma','results_staci', ...
    'branch_hop_weighted_entropy_rank45.mat'));
assert(report.has_balerma_rank45_design, ...
    'The released Balerma 45-pipe branch-hop design is missing.');
fprintf('MATLAB %s (%s); STACI MEX ready.\n', ...
    report.matlab_version,report.matlab_release);
disp(report.networks);
end
