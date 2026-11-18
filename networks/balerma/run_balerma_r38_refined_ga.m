function output_file=run_balerma_r38_refined_ga( ...
        paper_root,staci_root,mex_dir,objective,maximum_wall_seconds)
%RUN_BALERMA_R38_REFINED_GA Retry GA from feasible R38-anchor seeds.
% Reads the deterministic feasible population built by
% CREATE_BALERMA_R38_FEASIBLE_POPULATION. Writes a separate candidate MAT;
% it never replaces a previously audited final design automatically.
if nargin<5 || isempty(maximum_wall_seconds),maximum_wall_seconds=1800;end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
objective=string(objective);
assert(ismember(objective,string(cfg.objectives)));
seed_file=fullfile(cfg.results_dir,'feasible_populations', ...
    objective+".mat");
assert(isfile(seed_file), ...
    'Run create_balerma_r38_feasible_population first');
seed=load(seed_file,'population','best_x');
assert(size(seed.population,2)==numel(cfg.design_link_ids));
cfg.ga.seed_designs.(char(objective))=seed.best_x;
cfg.ga.additional_seed_designs=seed.population(1:min(90, ...
    size(seed.population,1)),:);
if objective=="cost"
    greedy_file=fullfile(cfg.results_dir,'feasible_populations', ...
        'greedy_cost_seed.mat');
    if isfile(greedy_file)
        greedy=load(greedy_file,'x');
        cfg.ga.seed_designs.cost=double(greedy.x(:)');
        cfg.ga.additional_seed_designs=[double(greedy.x(:)'); ...
            cfg.ga.additional_seed_designs];
    end
end
if objective=="todini"
    repair_file=fullfile(cfg.results_dir,'feasible_populations', ...
        'todini_repaired_seed.mat');
    if isfile(repair_file)
        repaired=load(repair_file,'best_x');
        cfg.ga.seed_designs.todini=double(repaired.best_x(:)');
        cfg.ga.additional_seed_designs=[double(repaired.best_x(:)'); ...
            cfg.ga.additional_seed_designs];
    end
end
cfg.ga.maximum_wall_seconds=maximum_wall_seconds;
output_dir=fullfile(cfg.results_dir,'refined_ga');
if ~isfolder(output_dir),mkdir(output_dir);end
output_file=fullfile(output_dir,objective+".mat");
result=wdn.optimize_staci_single_objective( ...
    cfg,char(objective),cfg.inp_file,output_file);
result.nominal_pressure_anchor_node_ids={'38'};
result.nominal_physical_reservoir_node_ids={'43','44','88'};
result.physical_replay_reservoir_node_ids={'38','43','44','88'};
result.feasible_population_file=fullfile('feasible_populations', ...
    objective+".mat");
save(output_file,'result','-v7');
fprintf('REFINED %s: objective %.9g, generation %d, %.1f s, violation %.4g\n', ...
    objective,result.metrics.(char(objective)),result.ga_last_generation, ...
    result.elapsed_time_seconds,result.max_constraint_violation);
end
