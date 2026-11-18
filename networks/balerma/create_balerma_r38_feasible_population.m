function output_file=create_balerma_r38_feasible_population( ...
        paper_root,staci_root,mex_dir,objective,n_trials)
%CREATE_BALERMA_R38_FEASIBLE_POPULATION Find feasible in-memory GA starts.
% A narrow R38 head band makes a random 454-dimensional GA population
% mostly infeasible. Coordinate perturbations around independently checked
% designs supply feasible starts without changing the objective or bounds.
% This is a documented seed search; final designs still require GA and
% independent EPANET validation.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
if nargin<5 || isempty(n_trials),n_trials=1500;end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
objective=string(objective);
assert(ismember(objective,string(cfg.objectives)));
direction=1;
if objective=="cost",direction=-1;end
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[link_order,original]=wdn.staci_input_link_template( ...
    cfg.inp_file,st,0.001);
baseline=string(cfg.objectives);
population=zeros(0,numel(cfg.design_link_ids));
best_value=-inf;
best_x=[];
for name=baseline
    file=fullfile(cfg.results_dir,name+".mat");
    if ~isfile(file),continue;end
    saved=load(file,'result');
    if ~strcmp(saved.result.constraint_set_id,cfg.constraint_set_id),continue;end
    x=double(saved.result.design_diameters(:)');
    [metrics,violation]=wdn.evaluate_staci_design( ...
        st,cfg,x,link_order,original);
    if violation>cfg.ga.constraint_tolerance,continue;end
    population(end+1,:)=x; %#ok<AGROW>
    value=direction*double(metrics.(char(objective)));
    if value>best_value,best_value=value;best_x=x;end
end
assert(~isempty(best_x),'No feasible Balerma R38-anchor starting design');
rng(cfg.ga.random_seed+213,'twister');
accepted=0;
improvements=0;
steps=[0.1,1,5,20,60]; % millimetres, all clipped to the common bounds
for iteration=1:n_trials
    if rand<0.8 || isempty(population)
        x=best_x;
    else
        x=population(randi(size(population,1)),:);
    end
    k=randi(numel(x));
    step=steps(randi(numel(steps)));
    x(k)=min(max(x(k)+step*sign(randn), ...
        cfg.minimum_diameter),cfg.maximum_diameter);
    try
        [metrics,violation]=wdn.evaluate_staci_design( ...
            st,cfg,x,link_order,original);
    catch
        continue
    end
    if violation>cfg.ga.constraint_tolerance,continue;end
    accepted=accepted+1;
    value=direction*double(metrics.(char(objective)));
    if value>best_value+1e-10
        best_value=value;
        best_x=x;
        improvements=improvements+1;
    end
    if size(population,1)<90
        population(end+1,:)=x; %#ok<AGROW>
    elseif rand<0.1
        population(randi(size(population,1)),:)=x;
    end
    if mod(iteration,300)==0
        fprintf('%s feasible seeds: %d/%d, best %.9g\n', ...
            objective,accepted,iteration,direction*best_value);
    end
end
population=[best_x;population]; %#ok<AGROW>
output_dir=fullfile(cfg.results_dir,'feasible_populations');
if ~isfolder(output_dir),mkdir(output_dir);end
output_file=fullfile(output_dir,objective+".mat");
objective_value=direction*best_value;
save(output_file,'population','best_x','best_value', ...
    'objective_value', ...
    'accepted','improvements','n_trials','-v7');
fprintf('%s feasible population: %d/%d accepted, %d improvements, best %.9g\n', ...
    objective,accepted,n_trials,improvements,objective_value);
end
