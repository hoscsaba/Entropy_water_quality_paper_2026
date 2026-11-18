function output_files = plot_ranking_pair_matrix(cfg,left_study,right_study,basename)
%PLOT_RANKING_PAIR_MATRIX Show two saved restricted optimization studies.
% Each upper panel is the objective actually optimized in that column.
% The five lower panels evaluate other metrics on those same diameters.
% This function only reads archived results: no hydraulic solve or GA.

metrics = {'cost','hydraulic_entropy','branch_hop_weighted_entropy', ...
    'chlorine_concentration','chlorine_entropy','todini'};
k_left=double(left_study.k(:)');
k_right=double(right_study.k(:)');
assert(isequal(k_left,k_right) && k_left(1)==0 && ...
    k_left(end)<=numel(cfg.design_link_ids) && all(diff(k_left)>0), ...
    'Both studies must share increasing subset sizes within the network.');
assert(isequal(string(left_study.criterion_keys), ...
    string(right_study.criterion_keys)), ...
    'The two columns must use the same pipe-ranking criteria.');
assert(numel(left_study.criterion_labels)==5, ...
    'Expected five fixed pipe-ranking criteria.');
assert(ismember(left_study.objective,metrics) && ...
    ismember(right_study.objective,metrics), ...
    'Unknown optimized objective.');

labels = struct( ...
    'cost','Cost (%) (\leftarrow better)', ...
    'hydraulic_entropy','Hyd. entropy (%) (better \rightarrow)', ...
    'branch_hop_weighted_entropy','BH entropy (%) (better \rightarrow)', ...
    'chlorine_concentration','Cl concentration (%) (better \rightarrow)', ...
    'chlorine_entropy','Cl entropy (%) (better \rightarrow)', ...
    'todini','Todini (%) (better \rightarrow)');
short_names = struct( ...
    'cost','cost','hydraulic_entropy','hydraulic entropy', ...
    'branch_hop_weighted_entropy','branch-hop entropy', ...
    'chlorine_concentration','chlorine concentration', ...
    'chlorine_entropy','chlorine entropy','todini','Todini index');
left_order = [{left_study.objective}, ...
    metrics(~strcmp(metrics,left_study.objective))];
right_order = [{right_study.objective}, ...
    metrics(~strcmp(metrics,right_study.objective))];
colors = lines(5);
markers = {'o','s','^','d','v'};
x = 100*double(left_study.k)/numel(cfg.design_link_ids);
fig = figure('Color','w','Position',[100 50 1400 1820]);
t = tiledlayout(fig,6,2,'TileSpacing','loose','Padding','compact');
for row = 1:6
    ax_left = nexttile(t);
    handles = plot_panel(ax_left,x,relative_metric(left_study,left_order{row}), ...
        labels.(left_order{row}),colors,markers);
    if row==1
        first_axis = ax_left;
        first_handles = handles;
        title(ax_left,objective_title(left_study.objective,short_names), ...
            'FontSize',15,'FontWeight','bold');
    elseif row==2
        title(ax_left,'Other objectives evaluated on these designs', ...
            'FontSize',13,'FontWeight','normal','FontAngle','italic');
    end
    ax_right = nexttile(t);
    plot_panel(ax_right,x,relative_metric(right_study,right_order{row}), ...
        labels.(right_order{row}),colors,markers);
    if row==1
        title(ax_right,objective_title(right_study.objective,short_names), ...
            'FontSize',15,'FontWeight','bold');
    elseif row==2
        title(ax_right,'Other objectives evaluated on these designs', ...
            'FontSize',13,'FontWeight','normal','FontAngle','italic');
    end
end
lgd = legend(first_axis,first_handles,left_study.criterion_labels, ...
    'Orientation','horizontal','NumColumns',5,'FontSize',14,'Box','off');
lgd.Layout.Tile = 'north';
xlabel(t,'Pipes released for optimization (%)','FontSize',18);

if ~isfolder(cfg.figures_dir), mkdir(cfg.figures_dir); end
png_file = fullfile(cfg.figures_dir,[basename '.png']);
svg_file = fullfile(cfg.figures_dir,[basename '.svg']);
exportgraphics(fig,png_file,'Resolution',cfg.plot.resolution);
exportgraphics(fig,svg_file,'ContentType','vector');
close(fig);
output_files = {png_file,svg_file};
end

function title_text = objective_title(objective,names)
if strcmp(objective,'cost')
    direction = 'minimize';
else
    direction = 'maximize';
end
title_text = sprintf('Optimized for %s (%s)',names.(objective),direction);
end

function values = relative_metric(study,name)
idx = find(strcmp(study.metric_names,name),1);
assert(~isempty(idx),'Missing saved metric %s',name);
values = reshape(study.metrics(:,:,idx), ...
    size(study.metrics,1),size(study.metrics,2));
values(~study.is_feasible)=NaN;
baseline = study.original_metrics.(name);
assert(isfinite(baseline) && abs(baseline)>eps, ...
    'A finite nonzero original value is required for %s',name);
values = 100*(values/baseline-1);
end

function handles = plot_panel(ax,x,values,y_label,colors,markers)
hold(ax,'on');
handles = gobjects(size(values,1),1);
for q=1:size(values,1)
    handles(q) = plot(ax,x,values(q,:),'-','Color',colors(q,:), ...
        'Marker',markers{q},'LineWidth',1.6,'MarkerSize',5.2, ...
        'MarkerFaceColor','w');
end
plot(ax,0,0,'ko','MarkerFaceColor','k','MarkerSize',5.5, ...
    'HandleVisibility','off');
grid(ax,'on'); box(ax,'on');
x_max=max(x);
x_pad=max(0.02*x_max,0.2);
xlim(ax,[-x_pad,x_max+x_pad]);
if x_max<=20
    xticks(ax,0:5:20);
else
    xticks(ax,0:25:100);
end
limits = ylim(ax);
pad = max(0.04*diff(limits),1e-6);
ylim(ax,limits+[-pad pad]);
ytickformat(ax,'%.3g');
ylabel(ax,y_label,'FontSize',13);
ax.FontSize = 14;
end
