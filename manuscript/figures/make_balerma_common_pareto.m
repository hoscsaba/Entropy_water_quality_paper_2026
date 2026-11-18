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
        'results_staci_r38_anchor_r44_physical_0p1_64in_v1', ...
        'pareto_r38_unavailable_study');
end
if nargin<3 || isempty(figure_dir)
    figure_dir=fullfile(network_dir, ...
        'figures_staci_r38_anchor_v1');
end
if nargin<4 || isempty(disabled_reservoir)
    disabled_reservoir="r38_anchor_r38_unavailable";
end
disabled_reservoir=string(disabled_reservoir);
if disabled_reservoir=="R38"
    replay_folder='pareto_failure_replay_r38';
    output_suffix='_r38';
elseif disabled_reservoir=="R44"
    replay_folder='pareto_failure_replay_r44';
    output_suffix='_r44';
elseif disabled_reservoir=="R43"
    replay_folder='pareto_failure_replay';
    output_suffix='';
elseif disabled_reservoir=="all_four"
    replay_folder='pareto_failure_replay_all_four';
    output_suffix='_all_four';
elseif disabled_reservoir=="protected_r44"
    replay_folder=fullfile('protected_connector_stress','pareto_pooled');
    output_suffix='_protected_r44';
elseif disabled_reservoir=="protected_all_four"
    replay_folder=fullfile('protected_connector_stress','pareto_all_four');
    output_suffix='_protected_all_four';
elseif disabled_reservoir=="r38_anchor_protected_all_four"
    replay_folder='pareto_failure_replay_protected_all_four';
    output_suffix='_r38_anchor_protected_all_four';
elseif disabled_reservoir=="r38_anchor_r38_unavailable"
    replay_folder='pareto_failure_replay_r38_unavailable';
    output_suffix='_r38_anchor_r38_unavailable';
else
    error('Unsupported Balerma source-state replay');
end
service=readtable(fullfile(result_dir,replay_folder, ...
    'pareto_failure_service.csv'));
n=height(service);
if disabled_reservoir=="all_four"
    expected_cases=454;
elseif ismember(disabled_reservoir, ...
        ["protected_all_four","r38_anchor_protected_all_four", ...
         "r38_anchor_r38_unavailable"])
    expected_cases=448;
elseif disabled_reservoir=="protected_r44"
    expected_cases=896;
else
    expected_cases=908;
end
assert(n>=2 && all(service.ArchiveIndex(:)>0) && ...
    numel(unique(service.ArchiveIndex))==n && ...
    all(service.FailureCases==expected_cases) && ...
    all(service.NonconvergentScenarios==0), ...
    'Balerma Pareto designs need a complete converged PDA replay');
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
if ~ismember(disabled_reservoir, ...
        ["r38_anchor_protected_all_four","r38_anchor_r38_unavailable"])
    assert(diff(water_limits)>1e-9 && diff(cl_limits)>1e-9, ...
        'Observed service scales need distinct values');
end
if diff(cl_limits)>1e-9
    area=36+132*(cl_limits(2)-chlorine)/diff(cl_limits);
else
    area=102*ones(size(chlorine));
end
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 17.5 12.5]);
ax=axes(fig);
ax.Color='w';ax.XColor='k';ax.YColor='k';
ax.GridColor=[0.82 0.82 0.82];ax.GridAlpha=0.6;
hold(ax,'on');
plot(ax,cost,entropy,'-','Color',[0.55 0.55 0.55], ...
    'LineWidth',0.9,'HandleVisibility','off');
scatter(ax,cost,entropy,area,water,'filled', ...
    'MarkerEdgeColor',[0.15 0.15 0.15], ...
    'LineWidth',0.45,'HandleVisibility','off');
if ismember(disabled_reservoir, ...
        ["all_four","r38_anchor_protected_all_four", ...
         "r38_anchor_r38_unavailable"])
    % One sequential scale preserves the ordering of service values.
    map=parula(256);
else
    map=interp1([0 0.5 1], ...
        [0.76 0.13 0.12;0.98 0.78 0.20;0.08 0.55 0.25], ...
        linspace(0,1,256)');
end
colormap(ax,map);
cb=colorbar(ax);
if ismember(disabled_reservoir, ...
        ["r38_anchor_protected_all_four","r38_anchor_r38_unavailable"])
    % Use a continuous scale appropriate to each physical source state.
    if disabled_reservoir=="r38_anchor_r38_unavailable"
        bounds=[45 55];
        assert(all(water>=bounds(1) & water<=bounds(2)), ...
            'R38-unavailable worst service exceeds the 45--55% scale');
    else
        % P433 caps most all-four designs near 85.75%.
        bounds=[floor(min(water)*10)/10,ceil(max(water)*10)/10];
        if diff(bounds)<0.2,bounds=bounds+[-0.1 0.1];end
    end
    clim(ax,bounds);
    cb.Ticks=linspace(bounds(1),bounds(2),5);
    cb.TickLabels=compose('%.1f',cb.Ticks);
elseif disabled_reservoir=="all_four"
    % The observed 53.36--54.24% interval needs a narrow absolute scale:
    % 0--100% hides every contrast, while 50--55% contains all points.
    assert(all(water>=50 & water<=55), ...
        'All-four service moved outside the declared color scale');
    clim(ax,[50 55]);
    cb.Ticks=50:55;
    cb.TickLabels=compose('%d',cb.Ticks);
elseif ismember(disabled_reservoir, ...
        ["R38","R44","protected_r44","protected_all_four"])
    clim(ax,[0 100]);
    cb.Ticks=[0 25 50 75 100];
    cb.TickLabels={'0','25','50','75','100'};
else
    clim(ax,water_limits);
    cb.Ticks=[water_limits(1),mean(water_limits),water_limits(2)];
    cb.TickLabels=compose('%.1f',cb.Ticks);
end
cb.Label.String='Worst water service [%]';
cb.FontSize=11;cb.Label.FontSize=11;cb.Color='k';
xlabel(ax,'Cost [10^6 relative units]');
ylabel(ax,'Branch-hop entropy [nat]');
ax.FontSize=11;ax.LineWidth=0.8;grid(ax,'on');box(ax,'on');
xpad=max(0.04*(max(cost)-min(cost)),0.01);
ypad=max(0.07*(max(entropy)-min(entropy)),0.01);
xlim(ax,[min(cost)-xpad,max(cost)+xpad]);
ylim(ax,[min(entropy)-ypad,max(entropy)+ypad]);
if disabled_reservoir=="r38_anchor_protected_all_four"
    % Mark two observed service thresholds, using the least-cost design
    % satisfying both water and chlorine-compliant worst-case delivery.
    thresholds=[85.0 85.5];
    xspan=max(cost)-min(cost);
    yspan=max(entropy)-min(entropy);
    xtext=min(cost)+0.50*xspan;
    ytext=min(entropy)+[0.20 0.47]*yspan;
    for k=1:numel(thresholds)
        j=find(water>=thresholds(k) & ...
            chlorine>=thresholds(k),1,'first');
        if isempty(j),continue;end
        text(ax,xtext,ytext(k), ...
            sprintf('Both >= %.1f%%\nw.w. %.2f%%\nCl.w. %.2f%%', ...
            thresholds(k),water(j),chlorine(j)), ...
            'FontSize',11,'Color',[0.18 0.18 0.18], ...
            'VerticalAlignment','middle','BackgroundColor','w', ...
            'Margin',1,'Interpreter','none');
        quiver(ax,xtext-0.015*xspan,ytext(k)-0.025*yspan, ...
            cost(j)-xtext+0.015*xspan, ...
            entropy(j)-ytext(k)+0.025*yspan,0, ...
            'Color',[0.25 0.25 0.25], ...
            'LineWidth',0.8,'MaxHeadSize',0.12, ...
            'HandleVisibility','off');
    end
elseif disabled_reservoir=="r38_anchor_r38_unavailable"
    % Mark the first (least-cost) displayed design passing each strict
    % service threshold. The 45% threshold would include every point.
    thresholds=[46 50];
    xspan=max(cost)-min(cost);
    yspan=max(entropy)-min(entropy);
    label_y=min(entropy)+[0.30 0.52]*yspan;
    for k=1:numel(thresholds)
        j=find(water>thresholds(k) & ...
            chlorine>thresholds(k),1,'first');
        assert(~isempty(j), ...
            'No displayed design passes both %g%% thresholds', ...
            thresholds(k));
        if k==1
            % Keep the lower callout at its previous location; only its
            % leader moves to the newly selected 46% design.
            label_x=min(cost)+0.468*xspan;
        else
            label_x=cost(j)+0.08*xspan;
        end
        % Leave a small gap before the midpoint of the box's left edge.
        arrow_x=label_x-0.015*xspan;
        arrow_y=label_y(k);
        text(ax,label_x,label_y(k), ...
            sprintf('Both > %g%%\nw.w. %.2f%%\nCl.w. %.2f%%', ...
            thresholds(k),water(j),chlorine(j)), ...
            'FontSize',11,'Color',[0.18 0.18 0.18], ...
            'HorizontalAlignment','left', ...
            'VerticalAlignment','middle','BackgroundColor','w', ...
            'Margin',1,'Interpreter','none');
        quiver(ax,arrow_x,arrow_y, ...
            cost(j)-arrow_x,entropy(j)-arrow_y,0, ...
            'Color',[0.25 0.25 0.25], ...
            'LineWidth',0.8,'MaxHeadSize',0.12, ...
            'HandleVisibility','off');
    end
end
ax.Units='normalized';ax.Position=[0.12 0.27 0.67 0.67];
cb.Units='normalized';cb.Position=[0.82 0.27 0.025 0.67];
if disabled_reservoir=="r38_anchor_r38_unavailable"
    % MATLAB's SVG exporter represents a ColorBar gradient as a tiled PNG
    % pattern; some viewers wrap its yellow top row onto the low end.
    % Overlay 256 adjacent vector strips so the 45--55% gradient remains
    % monotone in PDF, SVG, and raster previews alike.
    cb.Visible='off';
    bar=axes(fig,'Units','normalized', ...
        'Position',[0.82 0.27 0.025 0.67], ...
        'Color','w','YAxisLocation','right', ...
        'XLim',[0 1],'YLim',[45 55], ...
        'XTick',[],'YTick',45:2.5:55, ...
        'FontSize',11,'LineWidth',0.8,'Box','on');
    hold(bar,'on');
    bar.YTickLabel=compose('%.1f',bar.YTick);
    for k=1:size(map,1)
        % A small overlap prevents PDF antialiasing from leaving white
        % seams between adjacent vector strips.
        low=45+10*(k-1)/size(map,1)-0.012;
        high=45+10*k/size(map,1)+0.012;
        patch(bar,[0 1 1 0],[low low high high],map(k,:), ...
            'EdgeColor','none','HandleVisibility','off');
    end
    ylabel(bar,'Worst water service [%]','FontSize',11);
end
key=axes(fig,'Units','normalized', ...
    'Position',[0.21 0.045 0.56 0.115],'Visible','off');
hold(key,'on');
levels=unique([cl_limits(1),cl_limits(2)]);
for k=1:numel(levels)
    if diff(cl_limits)>1e-9
        marker_area=36+132*(cl_limits(2)-levels(k))/diff(cl_limits);
    else
        marker_area=102;
    end
    scatter(key,k,0.72,marker_area,[0.7 0.7 0.7], ...
        'filled','MarkerEdgeColor','k','LineWidth',0.45);
    text(key,k,0.25,sprintf('Cl worst %.1f%%',levels(k)), ...
        'HorizontalAlignment','center','FontSize',11,'Color','k');
end
if numel(levels)==1
    xlim(key,[0.4 1.6]);
else
    xlim(key,[0.4 2.6]);
end
ylim(key,[0 1.2]);
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
