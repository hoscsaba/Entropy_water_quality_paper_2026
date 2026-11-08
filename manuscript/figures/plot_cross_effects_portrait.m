function plot_cross_effects_portrait()
%PLOT_CROSS_EFFECTS_PORTRAIT Reflow saved cross-effects without simulations.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
source=fullfile(root,'results_staci','objective_relationships', ...
    'objective_relationship_summary.mat');
data=load(source,'cross_effects');
assert(numel(data.cross_effects)==2);
folder=fullfile(root,'manuscript','generated','figures');
metric_labels={'Cost','Hyd. ent.','Cl conc.','Cl ent.','Todini'};
objective_labels={'Cost','Hydraulic entropy','Cl concentration', ...
    'Cl entropy','Todini index'};
network_labels={'Anytown','Balerma'};
fig=figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[2 2 17 20]);
t=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
anchors=[.72 .10 .12;1 1 1;.08 .55 .25];
xi=linspace(0,1,257);
map=[interp1([0 .5 1],anchors(:,1),xi)', ...
     interp1([0 .5 1],anchors(:,2),xi)', ...
     interp1([0 .5 1],anchors(:,3),xi)'];
colormap(fig,map);
for n=1:2
    ax=nexttile(t,n);
    imagesc(ax,data.cross_effects{n}.column_normalized_color,[-1 1]);
    axis(ax,'image');
    title(ax,network_labels{n},'FontWeight','bold','FontSize',13);
    xticks(ax,1:5);xticklabels(ax,metric_labels);
    yticks(ax,1:5);yticklabels(ax,objective_labels);
    ylabel(ax,'Optimized objective');
    ax.FontSize=11;ax.TickLength=[0 0];
    for i=1:5
        for j=1:5
            value=data.cross_effects{n}.beneficial_change_percent(i,j);
            color=[0 0 0];
            if abs(data.cross_effects{n}.column_normalized_color(i,j))>.63
                color=[1 1 1];
            end
            text(ax,j,i,sprintf('%+.2g%%',value), ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontSize',11,'FontWeight','bold','Color',color);
        end
    end
end
cb=colorbar(ax);cb.Layout.Tile='east';
cb.Ticks=[-1 0 1];cb.TickLabels={'worse','neutral','better'};
cb.Label.String='Column-normalized beneficial change';
cb.FontSize=11;cb.Label.FontSize=11;
base=fullfile(folder,'figure14_objective_cross_effects_portrait');
exportgraphics(fig,[base '.png'],'Resolution',600);
exportgraphics(fig,[base '.svg'],'ContentType','vector');
close(fig);
fprintf('Created %s.png and .svg from saved data\n',base);
end
