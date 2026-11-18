function candidate=refine_balerma_cost_chlorine_local( ...
        paper_root,staci_root,mex_dir,objective_name,max_passes,start_file)
%REFINE_BALERMA_COST_CHLORINE_LOCAL Feasible one-pipe coordinate search.
% Audit the released GA incumbents for readily available improvements.
% All evaluations use the same resident STACI model and the same nominal
% pressure, chlorine and diameter constraints as the six Balerma GAs.
% The search is deterministic but local; it does not certify global optima.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
if nargin<4 || isempty(objective_name)
    objective_name="cost";
end
if nargin<5 || isempty(max_passes),max_passes=4;end
objective_name=string(objective_name);
assert(ismember(objective_name,["cost","chlorine_concentration"]));
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config(network_dir);
result_dir=fullfile(network_dir, ...
    'results_staci_uniform_0p1_64in_sourceentry_v4');
if nargin<6 || isempty(start_file)
    start_file=fullfile(result_dir,objective_name+".mat");
end
saved=load(start_file);
if isfield(saved,'result')
    x=double(saved.result.design_diameters(:)');
elseif isfield(saved,'candidate')
    x=double(saved.candidate.design_diameters(:)');
else
    error('Start MAT must contain result or candidate');
end
assert(numel(x)==454);
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
st=StaciModel(input_file);
release=onCleanup(@()st.release());
[link_order,original]=wdn.staci_input_link_template( ...
    input_file,st,0.001);
[metrics,violation]=wdn.evaluate_staci_design( ...
    st,cfg,x,link_order,original);
assert(violation<=cfg.ga.constraint_tolerance, ...
    'Coordinate-search seed is not feasible');
if objective_name=="cost"
    factors=[0.5,0.75,0.9,0.98];
    previous=metrics.cost;
else
    factors=[0.5,0.75,0.9,1.1,1.25,1.5];
    previous=metrics.chlorine_concentration;
end
out_dir=fullfile(result_dir,'objective_audit_refinement');
if ~isfolder(out_dir),mkdir(out_dir);end
if objective_name=="chlorine_concentration" && ...
        contains(string(start_file),'objective_audit_refinement/cost.mat')
    output_name="chlorine_concentration_from_cost.mat";
else
    output_name=objective_name+".mat";
end
filename=fullfile(out_dir,output_name);
total_evaluations=0;
started=tic;
fprintf('%s start: cost %.7g, Cl score %.12g\n', ...
    objective_name,metrics.cost,metrics.chlorine_concentration);
for pass=1:max_passes
    accepted=0;
    for i=1:numel(x)
        best_value=previous;best_d=x(i);
        for f=factors
            candidate_d=min(max(x(i)*f,cfg.minimum_diameter), ...
                cfg.maximum_diameter);
            if candidate_d==x(i),continue;end
            trial=x;trial(i)=candidate_d;
            total_evaluations=total_evaluations+1;
            try
                [m,v]=wdn.evaluate_staci_design( ...
                    st,cfg,trial,link_order,original);
                % Use an inward feasibility margin because repeated
                % hydraulic solves can differ slightly near an active
                % pressure bound. GA's 5e-5 allowance is too loose for
                % sequential coordinate moves.
                if v>1e-8,continue;end
                if objective_name=="cost"
                    improved=m.cost<best_value-1e-3;
                    value=m.cost;
                else
                    improved=m.chlorine_concentration>best_value+1e-7;
                    value=m.chlorine_concentration;
                end
                if improved
                    best_value=value;best_d=candidate_d;
                end
            catch
                % A failed candidate is simply infeasible, not an
                % alteration of the model or its accepted tolerances.
            end
        end
        if best_d~=x(i)
            x(i)=best_d;
            previous=best_value;
            accepted=accepted+1;
        end
    end
    [metrics,violation]=wdn.evaluate_staci_design( ...
        st,cfg,x,link_order,original);
    fprintf('Pass %d final independent violation %.9g\n',pass,violation);
    assert(violation<=cfg.ga.constraint_tolerance);
    candidate=struct('objective',char(objective_name), ...
        'design_diameters',x,'metrics',metrics, ...
        'max_constraint_violation',violation, ...
        'source_file',char(start_file), ...
        'pass',pass,'accepted_changes',accepted, ...
        'total_evaluations',total_evaluations, ...
        'elapsed_seconds',toc(started), ...
        'constraint_set_id',cfg.constraint_set_id, ...
        'method','deterministic feasible coordinate search');
    save(filename,'candidate','-v7');
    fprintf('%s pass %d: accepted %d, cost %.7g, Cl %.12g, violation %.3g, elapsed %.1f min\n', ...
        objective_name,pass,accepted,metrics.cost, ...
        metrics.chlorine_concentration,violation,toc(started)/60);
    if accepted==0,break;end
end
clear release st
end
