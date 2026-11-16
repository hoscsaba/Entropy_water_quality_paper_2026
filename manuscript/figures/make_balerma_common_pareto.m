function output_files=make_balerma_common_pareto(paper_root,result_dir,figure_dir,disabled_reservoir)
%MAKE_BALERMA_COMMON_PARETO Plot saved top-90 Pareto designs and PDA service.
% About 20 existing, numerically nondominated points are displayed at
% approximately uniform normalized-objective arclength. The complete
% archive and all per-point PDA replay rows remain in the results folder.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','balerma');
if nargin<2 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_staging');
end
if nargin<3 || isempty(figure_dir)
    figure_dir=fullfile(network_dir, ...
        'figures_staci_uniform_0p1_64in_staging');
end
if nargin<4 || isempty(disabled_reservoir),disabled_reservoir="R43";end
disabled_reservoir=string(disabled_reservoir);
if disabled_reservoir=="R38"
    replay_folder='pareto_failure_replay_r38';
    output_suffix='_r38';
elseif disabled_reservoir=="R43"
    replay_folder='pareto_failure_replay';
    output_suffix='';
else
    error('Only R38 or R43 outage replay can be plotted');
end
service=readtable(fullfile(result_dir,replay_folder, ...
    'pareto_failure_service.csv'));
n=height(service);
assert(n>=2 && isequal(service.ArchiveIndex(:),(1:n)') && ...
    all(service.FailureCases==908) && ...
    all(service.NonconvergentScenarios==0), ...
    'Every Balerma Pareto design needs 908 converged PDA cases');
% The service CSV contains both nominal Pareto coordinates and PDA outcomes,
% so the figure can be reproduced without loading the optimizer's MAT file.
[~,order]=sortrows([double(service.Cost(:)), ...
    -double(service.BranchHopEntropy(:))],[1 2]);
cost=double(service.Cost(order))/1e6;
entropy=double(service.BranchHopEntropy(order));
water=double(service.WaterWorstPct(order));
chlorine=double(service.ClWorstPct(order));
keep=false(n,1); best=-inf;
for k=1:n
    if entropy(k)>best+1e-9
        keep(k)=true;best=entropy(k);
    end
end
cost=cost(keep);entropy=entropy(keep);
water=water(keep);chlorine=chlorine(keep);
original_indices=order(keep);
assert(numel(cost)>=2,'Pareto archive needs two distinct points');
selected=sample_arclength(cost,entropy,min(20,numel(cost)));
selected_archive=original_indices(selected);
display_table=table(selected_archive,cost(selected),entropy(selected), ...
    water(selected),chlorine(selected), ...
    'VariableNames',{'ArchiveIndex','CostMillion','BranchHopEntropy', ...
    'WaterWorstPct','ClWorstPct'});
writetable(display_table,fullfile(result_dir, ...
    ['pareto_display_points' output_suffix '.csv']));
cost=cost(selected);entropy=entropy(selected);
water=water(selected);chlorine=chlorine(selected);
water_limits=[min(water),max(water)];
cl_limits=[min(chlorine),max(chlorine)];
assert(diff(water_limits)>1e-9 && diff(cl_limits)>1e-9, ...
    'Observed service scales need distinct values');
area=36+132*(cl_limits(2)-chlorine)/diff(cl_limits);
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 17.5 12.5]);
ax=axes(fig);hold(ax,'on');
plot(ax,cost,entropy,'-','Color',[0.55 0.55 0.55], ...
    'LineWidth',0.9,'HandleVisibility','off');
scatter(ax,cost,entropy,area,water,'filled', ...
    'MarkerEdgeColor',[0.15 0.15 0.15], ...
    'LineWidth',0.45,'HandleVisibility','off');
map=interp1([0 0.5 1], ...
    [0.76 0.13 0.12;0.98 0.78 0.20;0.08 0.55 0.25], ...
    linspace(0,1,256)');
colormap(ax,map);
cb=colorbar(ax);
if disabled_reservoir=="R38"
    % An absolute service scale avoids making a poor 40% outcome look good
    % merely because it is the best point in this finite Pareto archive.
    clim(ax,[0 100]);
    cb.Ticks=[0 25 50 75 100];
    cb.TickLabels={'0','25','50','75','100'};
else
    clim(ax,water_limits);
    cb.Ticks=[water_limits(1),mean(water_limits),water_limits(2)];
    cb.TickLabels=compose('%.1f',cb.Ticks);
end
cb.Label.String='Worst water service [%]';
cb.FontSize=11;cb.Label.FontSize=11;
xlabel(ax,'Cost [10^6 relative units]');
ylabel(ax,'Branch-hop entropy [nat]');
ax.FontSize=11;ax.LineWidth=0.8;grid(ax,'on');box(ax,'on');
xpad=max(0.04*(max(cost)-min(cost)),0.01);
ypad=max(0.07*(max(entropy)-min(entropy)),0.01);
xlim(ax,[min(cost)-xpad,max(cost)+xpad]);
ylim(ax,[min(entropy)-ypad,max(entropy)+ypad]);
ax.Units='normalized';ax.Position=[0.12 0.27 0.67 0.67];
cb.Units='normalized';cb.Position=[0.82 0.27 0.025 0.67];
key=axes(fig,'Units','normalized', ...
    'Position',[0.21 0.045 0.56 0.115],'Visible','off');
hold(key,'on');
levels=[cl_limits(1),cl_limits(2)];
for k=1:2
    marker_area=36+132*(cl_limits(2)-levels(k))/diff(cl_limits);
    scatter(key,k,0.72,marker_area,[0.7 0.7 0.7], ...
        'filled','MarkerEdgeColor','k','LineWidth',0.45);
    text(key,k,0.1,sprintf('Cl worst %.1f%%',levels(k)), ...
        'HorizontalAlignment','center','FontSize',11);
end
xlim(key,[0.4 2.6]);ylim(key,[0 1.2]);
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir, ...
    ['balerma_common_cost_branch_hop_failure_pareto' output_suffix]);
output_files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,output_files{1},'Resolution',450);
exportgraphics(fig,output_files{2},'ContentType','vector');
exportgraphics(fig,output_files{3},'ContentType','vector');
close(fig);
end

function selected=sample_arclength(cost,entropy,target_count)
n=numel(cost);
if target_count==n,selected=(1:n)';return;end
x=(cost(:)-min(cost))/max((max(cost)-min(cost)),eps);
y=(entropy(:)-min(entropy))/max((max(entropy)-min(entropy)),eps);
d=[0;cumsum(hypot(diff(x),diff(y)))];
if d(end)<=eps,d=linspace(0,1,n)';end
selected=[1;n];
while numel(selected)<target_count
    gap=min(abs(d-d(selected)'),[],2);
    gap(selected)=-inf;
    [~,next]=max(gap);
    selected(end+1,1)=next; %#ok<AGROW>
end
selected=sort(selected);
end
