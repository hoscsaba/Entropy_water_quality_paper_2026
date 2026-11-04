function report = audit_optimization_stopping(output_file, repo_root)
%AUDIT_OPTIMIZATION_STOPPING Summarize the 21 saved final single-objective runs.
if nargin<2 || strlength(string(repo_root))==0
    repo_root=fileparts(fileparts(mfilename('fullpath')));
end
if nargin<1 || strlength(string(output_file))==0
    output_file=fullfile(repo_root,'supplementary','results','optimization_stopping_21.csv');
end
addpath(repo_root);
networks=["tanyimboh_templeman","anytown","balerma"];
rows=cell(21,10);i=0;
for network=networks
    nd=fullfile(repo_root,'networks',char(network));addpath(nd);clear network_config;
    cfg=network_config(nd);
    for source=["archive","staci_ga"]
        if source=="archive",objectives=string(cfg.objectives);
        else,objectives=["chlorine_concentration","chlorine_entropy"];end
        for objective=objectives
            if source=="archive",p=fullfile(cfg.results_dir,objective+'.mat');
            else,p=fullfile(nd,'results_staci_constrained',objective+'.mat');end
            loaded=load(p,'result');r=loaded.result;o=r.output;
            if isfield(o,'ga'),ga=o.ga;else,ga=o;end
            message=string(ga.message);
            if contains(message,'MaxGenerations'),stop="generation_cap";
            elseif contains(message,'FunctionTolerance'),stop="function_tolerance";
            else,stop="other";end
            incumbent="optimizer result";
            if isfield(r,'incumbent_source'),incumbent=string(r.incumbent_source);end
            i=i+1;
            rows(i,:)={network,objective,source,ga.generations, ...
                cfg.ga.max_generations,ga.funccount,stop, ...
                r.optimizer_value,r.max_constraint_violation,incumbent};
        end
    end
    rmpath(nd);
end
report=cell2table(rows,'VariableNames',{'network','objective','design_source', ...
    'ga_generations','ga_generation_cap','fitness_evaluations','ga_stop_reason', ...
    'optimizer_value','max_constraint_violation','selected_incumbent'});
writetable(report,output_file);
fprintf('Audited %d saved single-objective runs; %d reached the generation cap.\n', ...
    height(report),nnz(report.ga_stop_reason=="generation_cap"));
end
