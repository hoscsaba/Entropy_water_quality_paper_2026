function results = make_two_consumer_entropy_example
%MAKE_TWO_CONSUMER_ENTROPY_EXAMPLE Two pipe-size solutions at maximum flow entropy.
% The common four-pipe INP has unequal demands D1=0.8 and D2=1.3 L/s.
% P0--P3 are S--J, J--D1, J--D2, D1--D2; all are 3 km long.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root,'-begin');
mini_dir=fullfile(root,'networks','y_two_consumers');
st=StaciModel(fullfile(mini_dir,'input','network_original.inp'));
cleanup=onCleanup(@()st.release());

D1=0.8;D2=1.3;Q=D1+D2;
% For x=Q3>=0, continuity gives (Q,Q1,Q2,Q3)=(Q,D1+x,D2-x,x).
% S_flow is the three-way entropy of the terminal paths D1,x,D2-x.
x_opt=fminbnd(@(x)-loop_entropy(x,D1,D2),0,D2);
assert(abs(x_opt-D2/2)<1e-5);
S_opt=loop_entropy(x_opt,D1,D2);
% Inverse STACI solve makes the hydraulic cross flow equal D2/2.
base=[100 80 NaN 60];
base(3)=fzero(@(d2)cross_flow([base(1:2),d2,base(4)])-x_opt,[40,70]);
diameter=[base;2*base];
flow=zeros(2,4);head=zeros(2,4);entropy=zeros(2,1);
node_entropy=zeros(2,4);
for k=1:2
 state=wdn.evaluate_two_consumer_staci(st,diameter(k,:));
 flow(k,:)=state.flow_Lps;
 head(k,:)=state.head_m;
 entropy(k)=state.hydraulic_entropy;
 node_entropy(k,:)=state.hydraulic_node_entropy;
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
  state=wdn.evaluate_two_consumer_staci(st,x);
  v=state.flow_Lps(4);
 end
end
function S=loop_entropy(x,D1,D2)
p=[D1,x,D2-x]/(D1+D2);p=p(p>0);
S=-sum(p.*log(p));
end
