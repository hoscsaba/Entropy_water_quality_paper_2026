function results = make_two_consumer_entropy_example
%MAKE_TWO_CONSUMER_ENTROPY_EXAMPLE Two pipe-size solutions at maximum flow entropy.
% The common four-pipe INP has unequal demands D1=0.8 and D2=1.3 L/s.
% P0--P3 are S--J, J--D1, J--D2, D1--D2; all are 3 km long.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root,'-begin');
anytown_dir=fullfile(root,'networks','anytown');
addpath(anytown_dir,'-begin');toolkit_cfg=network_config(anytown_dir);
rmpath(anytown_dir);wdn.setup_toolkit(toolkit_cfg);
mini_dir=fullfile(root,'networks','y_two_consumers');
cfg.inp_file=fullfile(mini_dir,'input','network_original.inp');
cfg.runtime_dir=fullfile(mini_dir,'runtime');
cfg.design_link_ids={'P0','P1','P2','P3'};
cfg.fixed_link_diameters=struct();cfg.entropy_excluded_link_ids={};
cfg.pressure_node_ids={'J','D1','D2'};cfg.quality_node_ids=cfg.pressure_node_ids;
cfg.numeric_tolerance=1e-9;cfg.epanet_library=toolkit_cfg.epanet_library;

D1=0.8;D2=1.3;Q=D1+D2;
% For x=Q3>=0, continuity gives (Q,Q1,Q2,Q3)=(Q,D1+x,D2-x,x).
% S_flow is the three-way entropy of the terminal paths D1,x,D2-x.
x_opt=fminbnd(@(x)-loop_entropy(x,D1,D2),0,D2);
assert(abs(x_opt-D2/2)<1e-5);
S_opt=loop_entropy(x_opt,D1,D2);
[d,model]=wdn.open_network(cfg);cleanup=onCleanup(@()d.unload);
d.setDemandModel('DDA',0,20,0.5);
link_ids=string(d.getLinkNameID);node_ids=string(d.getNodeNameID);
[okL,link_idx]=ismember(string(cfg.design_link_ids),link_ids);
[okN,node_idx]=ismember(["S","J","D1","D2"],node_ids);
assert(all(okL)&&all(okN));
% Inverse EPANET solve makes the hydraulic cross flow equal D2/2.
base=[100 80 NaN 60];
base(3)=fzero(@(d2)cross_flow([base(1:2),d2,base(4)])-x_opt,[40,70]);
diameter=[base;2*base];
flow=zeros(2,4);head=zeros(2,4);entropy=zeros(2,1);
node_entropy=zeros(2,4);
for k=1:2
 wdn.apply_design(d,diameter(k,:),cfg,model);d.solveCompleteHydraulics;
 q=double(d.getLinkFlows);flow(k,:)=q(link_idx)';
 h=double(d.getNodeHydraulicHead);head(k,:)=h(node_idx)';
 [entropy(k),details]=wdn.flow_entropy(d,model,[]);
 node_entropy(k,:)=details.node_entropy(node_idx)';
 assert(abs(details.source_entropy)<1e-12);
end
expected=[Q,D1+x_opt,D2-x_opt,x_opt];
assert(max(abs(flow-expected),[],'all')<1e-4);
assert(max(abs(diff(flow,1,1)),[],'all')<1e-4);
assert(max(abs(entropy-S_opt))<1e-5);
assert(min(head(:,3:4),[],'all')>20);
results=table(["A";"B"],diameter(:,1),diameter(:,2),diameter(:,3), ...
 diameter(:,4),flow(:,1),flow(:,2),flow(:,3),flow(:,4),entropy, ...
 head(:,1),head(:,2),head(:,3),head(:,4), ...
 'VariableNames',{'Design','D0_mm','D1_mm','D2_mm','D3_mm', ...
 'Q0_Lps','Q1_Lps','Q2_Lps','Q3_Lps','HydraulicEntropy_nat', ...
 'HeadS_m','HeadJ_m','HeadD1_m','HeadD2_m'});
results.EntropyS_nat=node_entropy(:,1);
results.EntropyJ_nat=node_entropy(:,2);
results.EntropyD1_nat=node_entropy(:,3);
results.EntropyD2_nat=node_entropy(:,4);
assert(max(abs(sum(node_entropy,2)-entropy))<1e-8);
results_dir=fullfile(mini_dir,'results');if ~isfolder(results_dir),mkdir(results_dir);end
writetable(results,fullfile(results_dir,'two_designs.csv'));
fig_dir=fullfile(root,'manuscript','generated','figures');
if ~isfolder(fig_dir),mkdir(fig_dir);end
plot_two_consumer_pair(diameter,flow,head,[],[D1 D2],entropy,'S_{\mathrm{flow}}', ...
 node_entropy, ...
 fullfile(fig_dir,'entropy_loop_two_consumers'));
clear cleanup
 function v=cross_flow(x)
  wdn.apply_design(d,x,cfg,model);d.solveCompleteHydraulics;
  qq=double(d.getLinkFlows);v=qq(link_idx(4));
 end
end
function S=loop_entropy(x,D1,D2)
p=[D1,x,D2-x]/(D1+D2);p=p(p>0);
S=-sum(p.*log(p));
end
