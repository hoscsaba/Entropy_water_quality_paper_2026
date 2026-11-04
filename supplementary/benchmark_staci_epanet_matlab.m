function benchmark_staci_epanet_matlab(results_dir, staci_root, mex_dir)
%BENCHMARK_STACI_EPANET_MATLAB Time in-memory steady chemistry vs EPANET EPS.
% Use the same fixed-load INP for both engines. The EPS duration is the first
% hour at which all node concentrations stayed within 1e-4 mg/L for 24 h.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'third_party', 'epanet_matlab_toolkit'));
addpath(fullfile(root, 'third_party', 'epanet_matlab_toolkit_patch'));
addpath(fullfile(staci_root, 'matlab'));
addpath(mex_dir);
library = fullfile(root, 'third_party', 'epanet22_arm64', 'libepanet2');
if nargin < 1 || strlength(string(results_dir)) == 0
    results_dir = fullfile(root, 'supplementary', 'results');
end
summary = readtable(fullfile(results_dir, 'summary.csv'), 'TextType', 'string');
rows = cell(height(summary), 9);
for case_number = 1:height(summary)
    network = summary.network(case_number);
    design = summary.design(case_number);
    folder = fullfile(results_dir, network, design);
    source = fullfile(folder, 'fixed_load.inp');
    duration_h = summary.convergence_h(case_number);
    if isnan(duration_h)
        duration_h = summary.duration_h(case_number);
    end
    input_text = fileread(source);
    expression = '(?im)^(\s*DURATION\s+)[^\r\n]+';
    replacement = sprintf('$1%d:00:00', round(duration_h));
    input_text = regexprep(input_text, expression, replacement, 'once');
    input_file = fullfile(folder, 'benchmark_to_convergence.inp');
    fid = fopen(input_file, 'w');
    fprintf(fid, '%s', input_text);
    fclose(fid);
    prior_dir = pwd;
    cd(folder);
    cd_cleanup = onCleanup(@() cd(prior_dir));
    ep = epanet('benchmark_to_convergence.inp', library);
    ep_cleanup = onCleanup(@() ep.unload);
    st = StaciModel(input_file);
    st_cleanup = onCleanup(@() st.release);
    ep_times = zeros(3, 1);
    st_times = zeros(3, 1);
    ep_cpu = zeros(3, 1);
    st_cpu = zeros(3, 1);
    st_repetitions = 2000;
    if network == "tanyimboh_templeman"
        ep_repetitions = 2000;
    else
        ep_repetitions = 200;
    end
    for trial = 1:3
        started = tic;
        cpu_started = cputime;
        for repeat = 1:st_repetitions
            status = st.solveHydraulics();
            assert(status.converged, 'STACI hydraulics failed');
            sq = st.solveSteadyQuality('chemical');
        end
        st_cpu(trial) = (cputime - cpu_started) / st_repetitions;
        st_times(trial) = toc(started) / st_repetitions;

        started = tic;
        cpu_started = cputime;
        for repeat = 1:ep_repetitions
            ep.solveCompleteHydraulics;
            ep.solveCompleteQuality;
            eq = double(ep.getNodeActualQuality);
        end
        ep_cpu(trial) = (cputime - cpu_started) / ep_repetitions;
        ep_times(trial) = toc(started) / ep_repetitions;
    end
    [found, match] = ismember(string(ep.getNodeNameID), string(sq.node_ids));
    assert(all(found), 'Node ID mismatch');
    max_error = max(abs(eq(:) - 1000 * sq.node_concentration_kgm3(match)));
    rows(case_number, :) = {network, design, duration_h, ...
        median(st_times), median(ep_times), ...
        median(st_cpu), median(ep_cpu), ...
        median(ep_cpu) / median(st_cpu), max_error};
    fprintf('%s / %s: STACI %.4g s; EPANET %.4g s; max diff %.4g mg/L\n', ...
        network, design, median(st_times), median(ep_times), max_error);
    clear st_cleanup ep_cleanup cd_cleanup st ep
end
result = cell2table(rows, 'VariableNames', ...
    {'network', 'design', 'convergence_h', 'staci_wall_s', ...
     'epanet_wall_s', 'staci_cpu_s', 'epanet_cpu_s', ...
     'epanet_over_staci_cpu', 'max_error_mgL'});
writetable(result, fullfile(results_dir, 'matlab_cpu_comparison.csv'));
end
