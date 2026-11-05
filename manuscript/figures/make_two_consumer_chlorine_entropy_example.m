function results = make_two_consumer_chlorine_entropy_example(run_optimization)
%MAKE_TWO_CONSUMER_CHLORINE_ENTROPY_EXAMPLE Nonunique near-optimal diameters.
% With no argument, rerun seeded GA; false replots the saved verified pair.
% Unequal demands (0.8,1.3 L/s) rule out consumer-swap symmetry.
% A second diameter set is obtained by inverse STACI sizing: keep P0/P1
% and the full flow vector fixed, change P3, then solve P2 for the same Q3.
% Terminal D2 has no outgoing split in this flow direction, so changing its
% chlorine concentration does not change the implemented chlorine entropy.
if nargin<1,run_optimization=true;end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(root,'-begin');
mini_dir=fullfile(root,'networks','y_two_consumers');
st=StaciModel(fullfile(mini_dir,'input','network_original.inp'));
cleanup=onCleanup(@()st.release());
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
fprintf('STACI pair: d3 %.3f/%.3f mm, D2 chlorine %.6f/%.6f mg/L, S %.9f/%.9f nat\n', ...
 diameter(1,4),diameter(2,4),chlorine(1,4),chlorine(2,4), ...
 entropy_cl(1),entropy_cl(2));
assert(abs(chlorine(1,4)-chlorine(2,4))>0.02, ...
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
  'exit_flag','output');
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
  state=wdn.evaluate_two_consumer_staci(st,x);
  q3=state.flow_Lps(4);
 end
 function [s,c,h,q,sh,node_s]=measure(x)
  state=wdn.evaluate_two_consumer_staci(st,x);
  s=state.chlorine_entropy;
  c=state.chlorine_mgL;
  h=state.head_m;
  q=state.flow_Lps;
  sh=state.hydraulic_entropy;
  node_s=state.chlorine_node_entropy;
 end
end
