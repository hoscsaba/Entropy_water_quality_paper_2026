function files=make_balerma_r43_p24_pareto(paper_root,result_dir,figure_dir)
%MAKE_BALERMA_R43_P24_PARETO Plot saved Pareto points under one compound fault.
% The 20 top-90 diameter vectors are unchanged. Colors and the lower trace
% report PDA demand served with R43 isolated and physical pipe P24 closed.
% The colorbar deliberately spans the observed 54--60% interval and is
% labelled as such; the ordinate in the lower panel shows exact values.
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
t=readtable(fullfile(result_dir,'pareto_r43_p24', ...
    'r43_p24_selected20.csv'));
t=sortrows(t,'CostMillion');
assert(height(t)==20 && all(isfinite(t.WaterServicePct)) && ...
    min(t.WaterServicePct)>=54 && max(t.WaterServicePct)<60 && ...
    max(abs(t.WaterServicePct- ...
    t.ChlorineCompliantServicePct))<0.01);
cost=double(t.CostMillion);
entropy=double(t.BranchHopEntropy);
served=double(t.WaterServicePct);
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 18.2 15.7]);
ax1=axes(fig,'Units','normalized', ...
    'Position',[0.12 0.56 0.64 0.38]);
hold(ax1,'on');
plot(ax1,cost,entropy,'-','Color',[0.55 0.55 0.55], ...
    'LineWidth',1,'HandleVisibility','off');
scatter(ax1,cost,entropy,70,served,'filled', ...
    'MarkerEdgeColor',[0.18 0.18 0.18], ...
    'LineWidth',0.55,'HandleVisibility','off');
map=interp1([0 0.5 1], ...
    [0.75 0.13 0.13;0.98 0.79 0.23;0.07 0.55 0.25], ...
    linspace(0,1,256)');
colormap(ax1,map);clim(ax1,[54 60]);
cb=colorbar(ax1);
cb.Ticks=[54 56 58 60];
cb.Label.String='R43 + P24: delivered demand [%]';
cb.FontSize=12.5;cb.Label.FontSize=12.5;cb.Color='k';
ylabel(ax1,'Branch-hop entropy [nat]');
style(ax1,cost);ylim(ax1,[29.2 30.8]);
ax1.Position=[0.12 0.56 0.64 0.38];
cb.Units='normalized';
cb.Position=[0.79 0.56 0.025 0.38];

ax2=axes(fig,'Units','normalized', ...
    'Position',[0.12 0.12 0.75 0.33]);
hold(ax2,'on');
plot(ax2,cost,served,'-o','Color',[0.04 0.42 0.70], ...
    'MarkerFaceColor',[0.04 0.42 0.70], ...
    'MarkerSize',3.6,'LineWidth',1.45);
style(ax2,cost);ylim(ax2,[53.5 61.5]);
ylabel(ax2,'Delivered demand [%]');
xlabel(ax2,'Cost [10^6 relative units]');
% Arrows report actual unmet demand, not an arbitrary service threshold.
text(ax2,cost(1)+0.27,54.7, ...
    sprintf('%.1f%% unmet',100-served(1)), ...
    'FontSize',12.5,'Color',[0.15 0.15 0.15]);
quiver(ax2,cost(1)+0.16,54.66, ...
    cost(1)-(cost(1)+0.16),served(1)-54.66,0, ...
    'Color',[0.15 0.15 0.15],'LineWidth',0.9, ...
    'MaxHeadSize',0.8,'HandleVisibility','off');
text(ax2,cost(end)-0.25,61.15, ...
    sprintf('%.1f%% unmet',100-served(end)), ...
    'HorizontalAlignment','right','FontSize',12.5, ...
    'Color',[0.15 0.15 0.15]);
quiver(ax2,cost(end)-0.25,60.93, ...
    0.25,served(end)-60.93,0, ...
    'Color',[0.15 0.15 0.15],'LineWidth',0.9, ...
    'MaxHeadSize',0.8,'HandleVisibility','off');
ax2.Position=[0.12 0.12 0.75 0.33];
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir,'balerma_r43_p24_cost_branch_hop_pareto');
files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,files{1},'Resolution',400);
exportgraphics(fig,files{2},'ContentType','vector');
exportgraphics(fig,files{3},'ContentType','vector');
close(fig);
end

function style(ax,cost)
ax.FontSize=12.5;ax.LineWidth=0.8;
ax.GridColor=[0.83 0.83 0.83];ax.GridAlpha=0.55;
grid(ax,'on');box(ax,'on');
xlim(ax,[min(cost)-0.15 max(cost)+0.15]);
end
