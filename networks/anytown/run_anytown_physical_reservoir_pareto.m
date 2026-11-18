function result=run_anytown_physical_reservoir_pareto( ...
        paper_root,staci_root,mex_dir,nominal_variant,result_dir_override, ...
        make_plot,force_optimization)
%RUN_ANYTOWN_PHYSICAL_RESERVOIR_PARETO Cost/branch-hop front, selected variant.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
if nargin<4,nominal_variant="physical_reservoirs";end
if nargin<5,result_dir_override=[];end
if nargin<6,make_plot=true;end
if nargin<7,force_optimization=false;end
if string(nominal_variant)=="anchor_replay"
    cfg=network_config_anchor_replay(network_dir);
else
    assert(string(nominal_variant)=="physical_reservoirs", ...
        'Unknown nominal variant');
    cfg=network_config_physical_reservoirs(network_dir);
end
if ~isempty(result_dir_override)
    cfg.results_dir=char(result_dir_override);
    cfg.figures_dir=fullfile(cfg.results_dir,'figures');
end
file=fullfile(cfg.results_dir,'multiobjective_cost_entropy.mat');
if isfile(file) && ~force_optimization
    saved=load(file,'result');result=saved.result;
    assert(isfield(result,'constraint_set_id') && ...
        strcmp(result.constraint_set_id, ...
        'pressure_10_120m_chlorine_mass_split_v2'), ...
        'Saved Pareto archive predates the common chlorine constraint');
    assert(isfield(result,'minimum_diameter') && ...
        abs(result.minimum_diameter-cfg.minimum_diameter)<1e-12 && ...
        isfield(result,'maximum_diameter') && ...
        abs(result.maximum_diameter-cfg.maximum_diameter)<1e-12, ...
        'Saved Pareto archive uses other diameter bounds');
else
    result=wdn.optimize_staci_cost_entropy_front(cfg,cfg.inp_file);
    save(file,'result','-v7.3');
end
if ~isfolder(cfg.figures_dir),mkdir(cfg.figures_dir);end
plot_result=result;
branch=load(fullfile(cfg.results_dir, ...
    'branch_hop_weighted_entropy.mat'),'result');
latest=branch.result;
plot_result.designs(end+1,:)=latest.design_diameters;
plot_result.cost(end+1,1)=latest.metrics.cost;
plot_result.branch_hop_entropy(end+1,1)= ...
    latest.metrics.branch_hop_weighted_entropy;
plot_result.chlorine_concentration(end+1,1)= ...
    latest.metrics.chlorine_concentration;
plot_result.chlorine_entropy(end+1,1)=latest.metrics.chlorine_entropy;
plot_result.max_constraint_violation(end+1,1)= ...
    latest.max_constraint_violation;
% Keep only nondominated points among the multiobjective archive and the
% subsequently improved single-objective endpoint.
n=numel(plot_result.cost);keep=true(n,1);
for j=1:n
    dominated=plot_result.cost<=plot_result.cost(j)+1e-8 & ...
        plot_result.branch_hop_entropy>= ...
        plot_result.branch_hop_entropy(j)-1e-10 & ...
        (plot_result.cost<plot_result.cost(j)-1e-8 | ...
        plot_result.branch_hop_entropy> ...
        plot_result.branch_hop_entropy(j)+1e-10);
    keep(j)=~any(dominated);
end
fields={'designs','cost','branch_hop_entropy', ...
    'chlorine_concentration','chlorine_entropy','max_constraint_violation'};
for j=1:numel(fields)
    key=fields{j};values=plot_result.(key);
    plot_result.(key)=values(keep,:);
end
[~,order]=sort(plot_result.cost);
for j=1:numel(fields)
    key=fields{j};values=plot_result.(key);
    plot_result.(key)=values(order,:);
end
save(fullfile(cfg.results_dir,'pareto_plot_archive.mat'), ...
    'plot_result','-v7.3');
if make_plot
    wdn.plot_cost_entropy_front(plot_result,cfg, ...
        fullfile(cfg.figures_dir,'figure7_cost_entropy.png'));
end
end
