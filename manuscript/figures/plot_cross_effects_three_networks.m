function plot_cross_effects_three_networks(output_dir)
%PLOT_CROSS_EFFECTS_THREE_NETWORKS Gaps from the best of six saved designs.
% Read archived nominal cross-evaluations; this only redraws the figure.
% For each network and objective, compare all six designs with the best
% saved value. Cost is minimized, while the other five scores are maximized.
% The common 0--100% fill scale is capped; cell labels retain larger gaps.
if nargin < 1
    output_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
        'manuscript','generated','figures');
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
files = {
    fullfile(root,'networks','tanyimboh_templeman', ...
      'results_staci_10_120_clsplit_v2','nominal_six_cross_evaluation.csv'), ...
    fullfile(root,'networks','anytown','results_staci_anchor_replay', ...
      'cross_evaluation_six_raw.csv'), ...
    fullfile(root,'networks','balerma', ...
      'results_staci_r38_anchor_r44_physical_0p1_64in_v1', ...
      'cross_evaluation_six_raw.csv')};
network_names = {'Tanyimboh–Templeman','Anytown','Balerma'};
metric_names = {'Cost','Flow S','Hop S','Cl conc.','Cl S','Todini'};
row_names = metric_names;
fig = figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[1 1 18 9.2]);
% A fixed green--cream--red scale makes the same percentage gap look the
% same in every objective column and network. It saturates at 100%.
anchors = [.10 .48 .24; 1.00 .95 .72; .70 .13 .15];
u = linspace(0,1,257);
cmap = [interp1([0 .5 1],anchors(:,1),u)', ...
        interp1([0 .5 1],anchors(:,2),u)', ...
        interp1([0 .5 1],anchors(:,3),u)'];
for k = 1:3
    T = readtable(files{k});
    assert(height(T)==6,'Expected six design rows in %s',files{k});
    if k==3
        x = T{:,{'Cost','HydraulicEntropy','BranchHopEntropy', ...
            'ChlorineConcentration','ChlorineEntropy','Todini'}};
    else
        x = T{:,{'Cost','FlowEntropy','BranchHopEntropy', ...
            'ChlorineConcentration','ChlorineEntropy','Todini'}};
    end
    assert(all(isfinite(x(:))) && all(x(:)>0), ...
        'Objective data must be finite and positive in %s',files{k});
    best = [min(x(:,1)) max(x(:,2:6),[],1)];
    gap = 100*(1-x./best);
    gap(:,1) = 100*(x(:,1)/best(1)-1);
    gap = max(gap,0); % Remove round-off-level negative gaps.

    ax = axes(fig,'Position',[.10+(k-1)*.31 .32 .26 .56]);
    imagesc(ax,min(gap,100),[0 100]);
    colormap(ax,cmap);
    set(ax,'YDir','reverse','XTick',1:6,'YTick',1:6, ...
        'XTickLabel',metric_names,'YTickLabel',row_names, ...
        'FontName','Helvetica','FontSize',10,'TickLength',[0 0]);
    xtickangle(ax,45);
    if k>1, set(ax,'YTickLabel',[]); end
    xlim(ax,[.5 6.5]); ylim(ax,[.5 6.5]);
    title(ax,network_names{k},'FontSize',11,'FontWeight','bold');
    hold(ax,'on');
    for boundary = .5:1:6.5
        line(ax,[boundary boundary],[.5 6.5], ...
            'Color',[.72 .72 .72],'LineWidth',.35);
        line(ax,[.5 6.5],[boundary boundary], ...
            'Color',[.72 .72 .72],'LineWidth',.35);
    end
    for i = 1:6
        for j = 1:6
            value = gap(i,j);
            fg = [0 0 0];
            if value<8 || value>=98, fg=[1 1 1]; end
            text(ax,j,i,gap_label(value), ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontName','Helvetica','FontSize',9,'Color',fg);
        end
    end
end
% A shared key explains the color fill without changing cell dimensions.
key = axes(fig,'Position',[.34 .055 .32 .023]);
imagesc(key,linspace(0,100,257),[0 100]);
colormap(key,cmap);
set(key,'YTick',[],'XTick',[1 129 257], ...
    'XTickLabel',{'0 (best)','50','100+'}, ...
    'FontName','Helvetica','FontSize',9,'TickLength',[0 0]);
title(key,'Gap from best saved value (%)', ...
    'FontName','Helvetica','FontSize',9,'FontWeight','normal');
if ~exist(output_dir,'dir'), mkdir(output_dir); end
base = fullfile(output_dir,'cross_effects_three_networks');
exportgraphics(fig,[base '.pdf'],'ContentType','vector');
exportgraphics(fig,[base '.svg'],'ContentType','vector');
exportgraphics(fig,[base '.png'],'Resolution',300);
close(fig);
fprintf('Wrote %s.{pdf,svg,png}\n',base);
end

function label = gap_label(value)
% Whole percentages suffice above 1%; retain small nonzero differences.
if value < 1e-9
    label = '0';
elseif value < 0.01
    label = '<.01';
elseif value < 1
    label = sprintf('%.2f',value);
else
    label = sprintf('%.0f',value);
end
end
