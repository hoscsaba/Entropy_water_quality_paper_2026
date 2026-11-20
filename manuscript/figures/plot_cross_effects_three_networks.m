function plot_cross_effects_three_networks(output_dir)
%PLOT_CROSS_EFFECTS_THREE_NETWORKS Three saved-design objective matrices.
% Reads only archived six-design CSVs. No hydraulic or optimization run is made.
% Each entry is the favorable percentage change from that network's saved
% minimum-cost design: lower cost and larger values of the other objectives
% are favorable. Color is normalized by metric within each network; the
% printed percentages carry the quantitative information.
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
network_names = {'Tanyimboh--Templeman','Anytown','Balerma'};
metric_names = {'Cost','Flow S','Hop S','Cl conc.','Cl S','Todini'};
row_names = {'Cost','Flow S','Hop S','Cl conc.','Cl S','Todini'};
fig = figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[1 1 18 8.5]);
anchors = [.73 .15 .16; 1 1 1; .13 .54 .24];
u = linspace(0,1,257);
cmap = [interp1([0 .5 1],anchors(:,1),u)', ...
        interp1([0 .5 1],anchors(:,2),u)', ...
        interp1([0 .5 1],anchors(:,3),u)'];
for k=1:3
    T=readtable(files{k});
    assert(height(T)==6,'Expected six design rows in %s',files{k});
    if k==3
        x=T{:,{'Cost','HydraulicEntropy','BranchHopEntropy', ...
            'ChlorineConcentration','ChlorineEntropy','Todini'}};
    else
        x=T{:,{'Cost','FlowEntropy','BranchHopEntropy', ...
            'ChlorineConcentration','ChlorineEntropy','Todini'}};
    end
    assert(all(isfinite(x(:))) && all(x(1,:)>0),'Invalid objective data');
    change=100*(x./x(1,:)-1);
    change(:,1)=-change(:,1);
    scaled=zeros(6);
    for j=1:6
        a=max(abs(change(:,j)));
        if a>0, scaled(:,j)=change(:,j)/a; end
    end
    ax=axes(fig,'Position',[.08+(k-1)*.325 .30 .255 .56]);
    imagesc(ax,scaled,[-1 1]); colormap(ax,cmap);
    set(ax,'YDir','reverse','XTick',1:6,'YTick',1:6, ...
        'XTickLabel',metric_names,'YTickLabel',row_names, ...
        'FontName','Helvetica','FontSize',9,'TickLength',[0 0]);
    xtickangle(ax,45);
    if k>1, set(ax,'YTickLabel',[]); end
    xlim(ax,[.5 6.5]); ylim(ax,[.5 6.5]);
    title(ax,network_names{k},'FontSize',11,'FontWeight','bold');
    hold(ax,'on');
    % Cell borders keep labels in the white, near-zero cells visually tied
    % to the same six-by-six grid as the colored entries.
    for boundary=.5:1:6.5
        line(ax,[boundary boundary],[.5 6.5], ...
            'Color',[.78 .78 .78],'LineWidth',.35);
        line(ax,[.5 6.5],[boundary boundary], ...
            'Color',[.78 .78 .78],'LineWidth',.35);
    end
    for i=1:6
        for j=1:6
            fg=[0 0 0]; if abs(scaled(i,j))>.67,fg=[1 1 1];end
            if abs(change(i,j))<0.5
                label='0';
            else
                label=sprintf('%+.0f',change(i,j));
            end
            text(ax,j,i,label, ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontName','Helvetica','FontSize',9,'Color',fg);
        end
    end
end
if ~exist(output_dir,'dir'),mkdir(output_dir);end
base=fullfile(output_dir,'cross_effects_three_networks');
exportgraphics(fig,[base '.pdf'],'ContentType','vector');
exportgraphics(fig,[base '.svg'],'ContentType','vector');
exportgraphics(fig,[base '.png'],'Resolution',300);
close(fig);
fprintf('Wrote %s.{pdf,svg,png}\n',base);
end
