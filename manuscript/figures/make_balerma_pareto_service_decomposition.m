function output_files=make_balerma_pareto_service_decomposition( ...
        paper_root,result_dir,figure_dir)
%MAKE_BALERMA_PARETO_SERVICE_DECOMPOSITION Explain service along Pareto set.
% Uses the 20 archived top-90 cost/branch-hop designs and their existing PDA
% replay checkpoints. No hydraulic, water-quality, or optimization run occurs.
% R44-only service is read from the saved P188 no-op row: P188 is already
% closed to isolate R44, so this row has no additional pipe failure.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(result_dir)
    result_dir=fullfile(paper_root,'networks','balerma', ...
        'results_staci_uniform_0p1_64in_sourceentry_v4');
end
if nargin<3 || isempty(figure_dir)
    figure_dir=fullfile(paper_root,'networks','balerma', ...
        'figures_staci_uniform_0p1_64in_sourceentry_v4');
end
archive=load(fullfile(result_dir,'pareto_cost_branch_hop_top90.mat'),'result');
selected=readtable(fullfile(result_dir,'pareto_selected20_indices.csv'));
ids=double(selected.ArchiveIndex(:));n=numel(ids);
assert(n==20 && numel(unique(ids))==20);
protected=["5","338","194","223","188","51"];
cost=double(archive.result.cost(ids))/1e6;
entropy=double(archive.result.branch_hop_entropy(ids));
baseline=zeros(n,1);mean_service=zeros(n,1);
worst10=zeros(n,1);worst=zeros(n,1);
for k=1:n
    f=fullfile(result_dir,'pareto_failure_replay_r44','checkpoints', ...
        sprintf('point_%04d.mat',ids(k)));
    saved=load(f,'all_cases','diameters');
    assert(isequal(double(saved.diameters(:)'), ...
        double(archive.result.designs(ids(k),:))), ...
        'PDA checkpoint and Pareto diameter vector differ');
    all_cases=saved.all_cases;
    no_failure=all_cases( ...
        string(all_cases.ReservoirAvailability)=="R44_unavailable" & ...
        string(all_cases.FailedLinkID)=="188",:);
    assert(height(no_failure)==1 && ~no_failure.Nonconvergent);
    baseline(k)=100*double(no_failure.DeliveredDemandFraction);
    cases=all_cases( ...
        string(all_cases.ReservoirAvailability)=="R44_unavailable" & ...
        ~ismember(string(all_cases.FailedLinkID),protected),:);
    assert(height(cases)==448 && all(~cases.Nonconvergent) && ...
        numel(unique(string(cases.FailedLinkID)))==448);
    service=sort(100*double(cases.DeliveredDemandFraction));
    mean_service(k)=mean(service);
    worst10(k)=mean(service(1:ceil(0.1*numel(service))));
    worst(k)=service(1);
end
[cost,order]=sort(cost);
ids=ids(order);entropy=entropy(order);baseline=baseline(order);
mean_service=mean_service(order);worst10=worst10(order);worst=worst(order);
assert(all(diff(entropy)>=-1e-6),'Selected points are not Pareto ordered');
metrics=table(ids,cost,entropy,baseline,mean_service,worst10,worst, ...
    baseline-mean_service,baseline-worst10,baseline-worst, ...
    'VariableNames',{'ArchiveIndex','CostMillion','BranchHopEntropy', ...
    'R44OnlyServicePct','R44Mean448Pct','R44Worst45MeanPct', ...
    'R44WorstPct','AdditionalMeanLossPp','AdditionalWorst45LossPp', ...
    'AdditionalWorstLossPp'});
writetable(metrics,fullfile(result_dir, ...
    'pareto_protected_r44_service_decomposition.csv'));

fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 18.2 21.5]);
t=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
gray=[0.20 0.20 0.20];blue=[0.12 0.39 0.75];
orange=[0.82 0.39 0.03];red=[0.70 0.17 0.17];

ax1=nexttile(t);hold(ax1,'on');
plot(ax1,cost,entropy,'-o','Color',[0.04 0.49 0.38], ...
    'MarkerFaceColor',[0.04 0.49 0.38], ...
    'MarkerSize',3.4,'LineWidth',1.35);
ylabel(ax1,'Branch-hop entropy [nat]');
title(ax1,'(a) Saved cost--entropy trade-off', ...
    'FontWeight','normal','FontSize',13.5);
style_axes(ax1,cost);ylim(ax1,[29.2 30.8]);

ax2=nexttile(t);hold(ax2,'on');
h(1)=plot(ax2,cost,baseline,'-o','Color',gray, ...
    'MarkerSize',3.5,'LineWidth',1.5);
h(2)=plot(ax2,cost,mean_service,'-s','Color',blue, ...
    'MarkerSize',3.2,'LineWidth',1.35);
h(3)=plot(ax2,cost,worst10,'-^','Color',orange, ...
    'MarkerSize',3.2,'LineWidth',1.35);
h(4)=plot(ax2,cost,worst,'-v','Color',red, ...
    'MarkerSize',3.2,'LineWidth',1.35);
ylabel(ax2,'Delivered demand [%]');
title(ax2,'(b) R44 unavailable: service after 0 or 1 pipe outage', ...
    'FontWeight','normal','FontSize',13.5);
style_axes(ax2,cost);ylim(ax2,[64 97]);

ax3=nexttile(t);hold(ax3,'on');
plot(ax3,cost,baseline-mean_service,'-s','Color',blue, ...
    'MarkerSize',3.2,'LineWidth',1.35);
plot(ax3,cost,baseline-worst10,'-^','Color',orange, ...
    'MarkerSize',3.2,'LineWidth',1.35);
plot(ax3,cost,baseline-worst,'-v','Color',red, ...
    'MarkerSize',3.2,'LineWidth',1.35);
ylabel(ax3,'Additional pipe-outage loss [pp]');
xlabel(ax3,'Cost [10^6 relative units]');
title(ax3,'(c) Pipe-loss component relative to each design''s R44-only state', ...
    'FontWeight','normal','FontSize',13.5);
style_axes(ax3,cost);ylim(ax3,[0 28]);
lgd=legend(ax2,h,{'R44 only (no pipe failure)', ...
    'Mean, 448 failures','Worst 45 mean','Worst single failure'}, ...
    'Orientation','horizontal','NumColumns',2,'FontSize',12.5);
lgd.Layout.Tile='south';
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir,'balerma_pareto_protected_r44_service_decomposition');
output_files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,output_files{1},'Resolution',400);
exportgraphics(fig,output_files{2},'ContentType','vector');
exportgraphics(fig,output_files{3},'ContentType','vector');
close(fig);
end

function style_axes(ax,cost)
ax.FontSize=13.5;ax.LineWidth=0.8;ax.GridColor=[0.83 0.83 0.83];
ax.GridAlpha=0.55;grid(ax,'on');box(ax,'on');
xlim(ax,[min(cost)-0.15 max(cost)+0.15]);
end
