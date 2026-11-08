function plot_cross_effects_portrait()
%PLOT_CROSS_EFFECTS_PORTRAIT Cross-evaluate six saved designs by six metrics.
% This reads released cross-evaluation CSVs, the original-design reference
% summary, and the archived K=0 branch-hop metric. No solver or GA is called.
% The Balerma branch-hop design varies only 45 of 454 physical pipes.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
summary=load(fullfile(root,'results_staci','objective_relationships', ...
    'objective_relationship_summary.mat'),'reference_metrics');
figure_dir=fullfile(root,'manuscript','generated','figures');
table_dir=fullfile(root,'manuscript','generated','tables');
metric_labels={'Cost','Flow ent.','Branch-hop', ...
    'Cl conc.','Cl ent.','Todini'};
objective_labels={'Cost','Flow ent.','Branch-hop', ...
    'Cl conc.','Cl ent.','Todini'};
network_ids={'anytown','balerma'};
network_labels={'Anytown','Balerma'};
anchors=[.72 .10 .12;1 1 1;.08 .55 .25];
xi=linspace(0,1,257);
map=[interp1([0 .5 1],anchors(:,1),xi)', ...
     interp1([0 .5 1],anchors(:,2),xi)', ...
     interp1([0 .5 1],anchors(:,3),xi)'];
for n=1:2
    network=network_ids{n};
    if n==1
        result_dir=fullfile(root,'networks','anytown', ...
            'results_staci_anchor_replay');
    else
        result_dir=fullfile(root,'networks','balerma','results_staci');
    end
    T=readtable(fullfile(result_dir,'cross_evaluation_six_raw.csv'));
    assert(height(T)==6 && width(T)==7,'Expected six saved designs and metrics');
    optimized=T{:,2:7};
    loaded=load(fullfile(result_dir,'ranking_cache', ...
        'branch_hop_weighted_entropy','volume','k_000.mat'),'entry');
    assert(loaded.entry.k==0,'Expected the unchanged original diameter vector');
    old_ref=summary.reference_metrics{n};
    reference=[old_ref(1:2), ...
        loaded.entry.metrics.branch_hop_weighted_entropy,old_ref(3:5)];
    keys={'cost','hydraulic_entropy','chlorine_concentration', ...
        'chlorine_entropy','todini'};
    for j=1:5
        actual=loaded.entry.metrics.(keys{j});
        assert(abs(actual-old_ref(j))<=1e-8*max(1,abs(actual)), ...
            'K=0 and published reference differ for %s',keys{j});
    end
    beneficial=100*(optimized./reference-1);
    beneficial(:,1)=-beneficial(:,1); % cost is minimized
    colors=zeros(6,6);
    for j=1:6
        span=max(abs(beneficial(:,j)));
        if span>0,colors(:,j)=beneficial(:,j)/span;end
    end
    out=array2table(beneficial,'VariableNames', ...
        {'Cost','FlowEntropy','BranchHopEntropy', ...
         'ChlorineConcentration','ChlorineEntropy','Todini'});
    out=addvars(out,string(T.OptimizedFor), ...
        'Before',1,'NewVariableNames','OptimizedFor');
    writetable(out,fullfile(table_dir, ...
        ['cross_effects_six_' network '.csv']));

    fig=figure('Visible','off','Color','w','Units','centimeters', ...
        'Position',[2 2 17 10.5]);
    ax=axes(fig,'Position',[.25 .20 .71 .70]);
    imagesc(ax,colors,[-1 1]);colormap(ax,map);
    axis(ax,'normal');xlim(ax,[.5 6.5]);ylim(ax,[.5 6.5]);
    title(ax,network_labels{n},'FontWeight','bold','FontSize',13);
    xticks(ax,1:6);xticklabels(ax,metric_labels);xtickangle(ax,20);
    yticks(ax,1:6);yticklabels(ax,objective_labels);
    ylabel(ax,'Optimized objective');
    ax.FontSize=11;ax.TickLength=[0 0];
    for i=1:6
        for j=1:6
            color=[0 0 0];
            if abs(colors(i,j))>.63,color=[1 1 1];end
            text(ax,j,i,sprintf('%+.2g%%',beneficial(i,j)), ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontSize',10,'FontWeight','bold','Color',color);
        end
    end
    base=fullfile(figure_dir, ...
        ['figure14_objective_cross_effects_' network]);
    exportgraphics(fig,[base '.png'],'Resolution',600);
    exportgraphics(fig,[base '.svg'],'ContentType','vector');
    close(fig);
    fprintf('Created %s.png and .svg from saved data\n',base);
end
end
