function results = make_two_consumer_chlorine_entropy_example(run_optimization)
%MAKE_TWO_CONSUMER_CHLORINE_ENTROPY_EXAMPLE Nonunique near-optimal diameters.
% With no argument, rerun seeded GA; false replots the saved verified pair.
% Unequal demands (0.8,1.3 L/s) rule out consumer-swap symmetry.
% A second diameter set is obtained by inverse EPANET sizing: keep P0/P1
% and the full flow vector fixed, change P3, then solve P2 for the same Q3.
% Terminal D2 has no outgoing split in this flow direction, so changing its
% chlorine concentration does not change the implemented chlorine entropy.
if nargin<1,run_optimization=true;end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(root,'-begin');
anytown_dir=fullfile(root,'networks','anytown');addpath(anytown_dir,'-begin');
toolkit_cfg=network_config(anytown_dir);rmpath(anytown_dir);
wdn.setup_toolkit(toolkit_cfg);
mini_dir=fullfile(root,'networks','y_two_consumers');
cfg.inp_file=fullfile(mini_dir,'input','network_original.inp');
cfg.runtime_dir=fullfile(mini_dir,'runtime');
cfg.design_link_ids={'P0','P1','P2','P3'};
cfg.fixed_link_diameters=struct();cfg.entropy_excluded_link_ids={};
cfg.pressure_node_ids={'J','D1','D2'};cfg.quality_node_ids={'D1','D2'};
cfg.numeric_tolerance=1e-9;cfg.epanet_library=toolkit_cfg.epanet_library;
cfg.quality_duration_hours=48;cfg.quality_step_hours=1/12;
cfg.bulk_reaction_coefficient=-1;cfg.source_chlorine=1;
cfg.source_node_ids={'S'};
[d,model]=wdn.open_network(cfg);cleanup=onCleanup(@()d.unload);
d.setDemandModel('DDA',0,20,0.5);
link_ids=string(d.getLinkNameID);node_ids=string(d.getNodeNameID);
[okL,link_idx]=ismember(string(cfg.design_link_ids),link_ids);
[okN,node_idx]=ismember(["S","J","D1","D2"],node_ids);
assert(all(okL)&&all(okN));
results_dir=fullfile(mini_dir,'results');if ~isfolder(results_dir),mkdir(results_dir);end
if run_optimization
 rng(1993,'twister');
 seed=[100 80 51.5819 60;200 160 103.1638 120; ...
       85 68 44 51;120 96 62 72;120 80 60 70;100 70 70 60];
 opts=optimoptions('ga','Display','off','PopulationSize',80, ...
   'MaxGenerations',100,'MaxStallGenerations',30, ...
   'FunctionTolerance',1e-9,'InitialPopulationMatrix',seed, ...
   'UseParallel',false);
 [best,~,exit_flag,output]=ga(@penalized_objective,4,[],[],[],[], ...
   40*ones(1,4),200*ones(1,4),[],opts);
 [best_entropy,~,~,best_flow]=measure(best);
 target_q3=best_flow(4);
 candidates=zeros(0,4);
 for d3=40:10:200
  x=best;x(4)=d3;
  try
   x(3)=fzero(@(d2)cross_flow([x(1:2),d2,x(4)])-target_q3,[40,200]);
   if x(3)<40||x(3)>200,continue;end
   [s,c,h]=measure(x);
   if min(h(3:4))>=20 && min(c(3:4))>=0.2 && ...
      abs(s-best_entropy)<1e-6
    candidates(end+1,:)=x; %#ok<AGROW>
   end
  catch
   % Candidate did not give a bracketed inverse flow solution.
  end
 end
 assert(size(candidates,1)>=2,'No distinct feasible entropy-matched pair.');
 diameter=candidates([1,end],:);
else
 saved=readtable(fullfile(results_dir,'chlorine_entropy_pair.csv'));
 diameter=[saved.D0_mm,saved.D1_mm,saved.D2_mm,saved.D3_mm];
 best=[];best_entropy=NaN;exit_flag=NaN;output=[];
end
entropy_cl=zeros(2,1);entropy_h=zeros(2,1);
flow=zeros(2,4);head=zeros(2,4);chlorine=zeros(2,4);
node_entropy=zeros(2,4);
for k=1:2
 [entropy_cl(k),chlorine(k,:),head(k,:),flow(k,:),entropy_h(k),node_entropy(k,:)] = ...
   measure(diameter(k,:));
end
assert(max(abs(diff(flow,1,1)),[],'all')<1e-5, ...
 'The two diameter sets do not have the same flow vector.');
assert(abs(diff(entropy_cl))<1e-6,'Chlorine entropy differs.');
assert(min(head(:,3:4),[],'all')>=20,'A pressure limit was violated.');
assert(min(chlorine(:,3:4),[],'all')>=0.2,'Chlorine below 0.2 mg/L.');
assert(abs(chlorine(1,4)-chlorine(2,4))>0.1, ...
 'The two designs do not show a meaningful quality difference.');
results=table(["A";"B"],diameter(:,1),diameter(:,2),diameter(:,3), ...
 diameter(:,4),flow(:,1),flow(:,2),flow(:,3),flow(:,4), ...
 entropy_cl,entropy_h,head(:,1),head(:,2),head(:,3),head(:,4), ...
 chlorine(:,1),chlorine(:,2),chlorine(:,3),chlorine(:,4), ...
 'VariableNames',{'Design','D0_mm','D1_mm','D2_mm','D3_mm', ...
 'Q0_Lps','Q1_Lps','Q2_Lps','Q3_Lps','ChlorineEntropy_nat', ...
 'HydraulicEntropy_nat','HeadS_m','HeadJ_m','HeadD1_m','HeadD2_m', ...
 'ChlorineS_mgL','ChlorineJ_mgL','ChlorineD1_mgL','ChlorineD2_mgL'});
results.EntropyS_nat=node_entropy(:,1);
results.EntropyJ_nat=node_entropy(:,2);
results.EntropyD1_nat=node_entropy(:,3);
results.EntropyD2_nat=node_entropy(:,4);
assert(max(abs(sum(node_entropy,2)-entropy_cl))<1e-8);
writetable(results,fullfile(results_dir,'chlorine_entropy_pair.csv'));
if run_optimization
 save(fullfile(results_dir,'chlorine_entropy_search.mat'), ...
  'best','best_entropy','diameter','entropy_cl','chlorine','flow','head', ...
  'exit_flag','output','cfg');
end
fig_dir=fullfile(root,'manuscript','generated','figures');
if ~isfolder(fig_dir),mkdir(fig_dir);end
plot_two_consumer_pair(diameter,flow,head,chlorine,[0.8 1.3], ...
 entropy_cl,'S_{\mathrm{Cl}}',node_entropy, ...
 fullfile(fig_dir,'chlorine_entropy_loop_pair'));
if run_optimization
 fprintf('GA best %.9f, matched pair %.9f/%.9f nat; evaluations %d.\n', ...
  best_entropy,entropy_cl(1),entropy_cl(2),output.funccount);
end
clear cleanup
 function score=penalized_objective(x)
  try
   [s,c,h]=measure(x);
   score=-s+10*max(0,20-min(h(3:4)))^2 ...
           +100*max(0,0.2-min(c(3:4)))^2;
  catch
   score=1e5;
  end
 end
 function q3=cross_flow(x)
  wdn.apply_design(d,x,cfg,model);d.solveCompleteHydraulics;
  q=double(d.getLinkFlows);q3=q(link_idx(4));
 end
 function [s,c,h,q,sh,node_s]=measure(x)
  wdn.apply_design(d,x,cfg,model);d.solveCompleteHydraulics;
  hh=double(d.getNodeHydraulicHead);h=hh(node_idx)';
  qq=double(d.getLinkFlows);q=qq(link_idx)';
  all_c=wdn.chlorine_state(d,cfg);c=all_c(node_idx)';
  [s,details]=wdn.flow_entropy(d,model,all_c);
  node_s=details.node_entropy(node_idx)';
  assert(abs(details.source_entropy)<1e-12);
  sh=wdn.flow_entropy(d,model,[]);
 end
end
