function output_file=greedy_balerma_r38_cost_seed( ...
        paper_root,staci_root,mex_dir,n_sweeps)
%GREEDY_BALERMA_R38_COST_SEED Make a feasible low-cost GA starting design.
% Try progressively smaller diameters one pipe at a time. Every accepted
% change is re-solved in resident STACI and satisfies the common pressure,
% R38 anchor, and consumer-chlorine constraints. This coordinate search is
% only a warm start, not a claim of global or local optimality.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
if nargin<4 || isempty(n_sweeps),n_sweeps=2;end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
seed_file=fullfile(cfg.results_dir,'feasible_populations','cost.mat');
assert(isfile(seed_file),'Create the feasible cost population first');
saved=load(seed_file,'best_x');
x=double(saved.best_x(:)');
st=StaciModel(cfg.inp_file);
release=onCleanup(@()st.release()); %#ok<NASGU>
[links,original]=wdn.staci_input_link_template(cfg.inp_file,st,0.001);
[m,v]=wdn.evaluate_staci_design(st,cfg,x,links,original);
assert(v<=cfg.ga.constraint_tolerance);
initial_cost=m.cost;
cost=m.cost;
accepted=0;
tested=0;
output_file=fullfile(cfg.results_dir,'feasible_populations', ...
    'greedy_cost_seed.mat');
start_sweep=1;
if isfile(output_file)
    previous=load(output_file,'x','cost','initial_cost', ...
        'accepted','tested','sweep');
    if previous.sweep>=n_sweeps
        fprintf('cost greedy: %d sweeps already complete, cost %.9g\n', ...
            previous.sweep,previous.cost);
        return
    end
    x=double(previous.x(:)');
    cost=previous.cost;
    initial_cost=previous.initial_cost;
    accepted=previous.accepted;
    tested=previous.tested;
    start_sweep=previous.sweep+1;
    [m,v]=wdn.evaluate_staci_design(st,cfg,x,links,original);
    assert(v<=cfg.ga.constraint_tolerance && abs(m.cost-cost)<1e-5, ...
        'Saved greedy checkpoint is incompatible with the R38 model');
end
rng(cfg.ga.random_seed+619+start_sweep,'twister');
for sweep=start_sweep:n_sweeps
    order=randperm(numel(x));
    improved=0;
    for position=1:numel(order)
        k=order(position);
        current=x(k);
        lower=[cfg.minimum_diameter,25.4,50,100,150,200,300,400, ...
            0.5*current,0.75*current,0.9*current,0.98*current];
        lower=unique(max(lower,cfg.minimum_diameter));
        lower=lower(lower<current-0.05);
        for candidate=lower
            y=x;
            y(k)=candidate;
            tested=tested+1;
            try
                [metrics,violation]=wdn.evaluate_staci_design( ...
                    st,cfg,y,links,original);
            catch
                continue
            end
            if violation>cfg.ga.constraint_tolerance || ...
                    metrics.cost>=cost-1e-7
                continue
            end
            x=y;
            cost=metrics.cost;
            accepted=accepted+1;
            improved=improved+1;
            break
        end
        if mod(position,100)==0
            fprintf('cost greedy sweep %d: %d/%d pipes, cost %.9g\n', ...
                sweep,position,numel(order),cost);
        end
    end
    save(output_file,'x','cost','initial_cost','accepted','tested', ...
        'n_sweeps','sweep','-v7');
    fprintf('cost greedy sweep %d: %d improvements, cost %.9g\n', ...
        sweep,improved,cost);
    if improved==0,break;end
end
[m,v]=wdn.evaluate_staci_design(st,cfg,x,links,original);
assert(v<=cfg.ga.constraint_tolerance && ...
    abs(m.cost-cost)<1e-5, 'Greedy cost seed lost feasibility');
save(output_file,'x','cost','initial_cost','accepted','tested', ...
    'n_sweeps','sweep','-v7');
end
