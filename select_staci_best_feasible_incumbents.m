function select_staci_best_feasible_incumbents(staci_root, mex_dir, network_name)
%SELECT_STACI_BEST_FEASIBLE_INCUMBENTS Share feasible elites across objectives.
% The archived GA run is retained; the reported incumbent is the best
% independently re-evaluated feasible design among all five final runs.
root = fileparts(mfilename('fullpath'));
network_dir = fullfile(root, 'networks', network_name);
result_dir = fullfile(network_dir, 'results_staci');
addpath(root, network_dir, fullfile(staci_root,'matlab'), mex_dir);
cfg = network_config(network_dir);
names = string(cfg.objectives);
input_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');
st = StaciModel(input_file);
cleanup = onCleanup(@() st.release()); %#ok<NASGU>
if strcmp(network_name,'anytown'), diameter_scale = 0.0254;
else, diameter_scale = 0.001;
end
[link_order, original_full] = wdn.staci_input_link_template( ...
    input_file, st, diameter_scale);
for i = 1:numel(names)
    saved = load(fullfile(result_dir,names(i)+'.mat'),'result');
    candidates{i} = saved.result; %#ok<AGROW>
    [metrics(i), hydraulic_violation(i)] = wdn.evaluate_staci_design( ...
        st,cfg,candidates{i}.design_diameters,link_order,original_full); %#ok<AGROW>
end
chlorine_floor = 0.2;
for i = 1:numel(names)
    target_file = fullfile(result_dir,names(i)+'.mat');
    saved = load(target_file,'result');
    result = saved.result;
    best_index = i;
    best_score = objective_score(metrics(i),names(i));
    for k = 1:numel(names)
        if hydraulic_violation(k) > cfg.ga.constraint_tolerance, continue; end
        if ismember(names(i),["chlorine_concentration","chlorine_entropy"]) && ...
                metrics(k).minimum_consumer_chlorine_mgL < chlorine_floor - ...
                cfg.ga.constraint_tolerance
            continue;
        end
        score = objective_score(metrics(k),names(i));
        if score < best_score - 1e-10
            best_index = k;
            best_score = score;
        end
    end
    if best_index == i, continue; end
    raw_file = fullfile(result_dir,names(i)+'_ga_raw.mat');
    if ~isfile(raw_file), save(raw_file,'result','-v7'); end
    donor = candidates{best_index};
    result.design_diameters = donor.design_diameters;
    result.full_diameters = metrics(best_index).full_diameters;
    result.metrics = metrics(best_index);
    result.max_constraint_violation = hydraulic_violation(best_index);
    result.optimizer_value = best_score;
    result.incumbent_source = ['cross-objective feasible elite: ' char(names(best_index))];
    result.incumbent_ga_raw_file = [char(names(i)) '_ga_raw.mat'];
    result.incumbent_selected_after_ga = true;
    save(target_file,'result','-v7');
    fprintf('%s/%s: selected %s design, objective %.9g\n', ...
        network_name,names(i),names(best_index),best_score);
end
end

function score = objective_score(metrics,name)
score = metrics.(char(name));
if name ~= "cost", score = -score; end
end
