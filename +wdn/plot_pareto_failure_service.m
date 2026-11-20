function plot_pareto_failure_service(archive, service, output_file, style, callout_centers)
%PLOT_PARETO_FAILURE_SERVICE Cost/branch-hop front with PDA failure service.
% Color encodes minimum water delivery across the network's specified pipe
% failure scenarios. Marker area encodes the minimum chlorine-compliant
% delivery across the same scenarios. Both measures use requested demand.
% The sparse inverse-Cl style uses the displayed service range, with red
% for low water service and green for 100%, and larger markers for lower
% chlorine-compliant service.
if nargin<4 || isempty(style),style="standard";end
if nargin<5,callout_centers=[];end
style=string(style);
if ~isempty(callout_centers)
    assert(style=="tt_inverse_cl" && isequal(size(callout_centers),[2 2]) ...
        && all(isfinite(callout_centers(:))), ...
        'Callout centers must be finite [cost, entropy] pairs for 75%% and 90%%');
end
assert(ismember(style,["standard","tt_inverse_cl"]), ...
    'Unknown Pareto service display style');
n=size(archive.designs,1);
assert(height(service)==n && isequal(service.ArchiveIndex(:),(1:n)'), ...
    'Every archived Pareto point must have one ordered failure-replay row');
assert(all(service.FailureCases==service.FailureCases(1)) && ...
    all(service.NonconvergentScenarios==0), ...
    'The failure replay is incomplete or contains unconverged cases');
assert(max(abs(service.Cost(:)-archive.cost(:)))<1e-6*max(archive.cost) && ...
    max(abs(service.BranchHopEntropy(:)- ...
    archive.branch_hop_entropy(:)))<1e-7, ...
    'Service rows do not match the plotted optimization archive');
[~,order]=sortrows([double(archive.cost(:)), ...
    -double(archive.branch_hop_entropy(:))],[1 2]);
cost=double(archive.cost(order))/1e6;
entropy=double(archive.branch_hop_entropy(order));
water=double(service.WaterWorstPct(order));
chlorine=double(service.ClWorstPct(order));
assert(all(isfinite([cost;entropy;water;chlorine])) && ...
    all(water>=-1e-6 & water<=100+1e-6) && ...
    all(chlorine>=-1e-6 & chlorine<=100+1e-6), ...
    'Non-finite or out-of-range Pareto service value');
% A finite GA archive can retain dominated points, especially when objective
% values differ only below solver precision. Keep the strictly improving
% cost-sorted envelope; every saved design remains in the replay CSV.
keep=false(n,1);
best_entropy=-inf;
for j=1:n
    if entropy(j)>best_entropy+1e-9
        keep(j)=true;
        best_entropy=entropy(j);
    end
end
fprintf('Pareto plot: %d/%d numerically nondominated points retained\n', ...
    nnz(keep),n);
cost=cost(keep); entropy=entropy(keep);
water=water(keep); chlorine=chlorine(keep);
if style=="tt_inverse_cl"
    % The TT archive is dense enough that plotting every candidate hides
    % the service colors. Preserve the first (lowest-cost) designs whose
    % two worst-service indicators exceed 75% and 90%, then fill the rest
    % of the 20 displayed positions by normalized objective arclength.
    thresholds=[75 90];
    threshold_indices=zeros(size(thresholds));
    for t=1:numel(thresholds)
        threshold_indices(t)=find(water>thresholds(t) & ...
            chlorine>thresholds(t),1,'first');
        assert(~isempty(threshold_indices(t)), ...
            'No Pareto design exceeds both %.0f%% service limits', ...
            thresholds(t));
    end
    threshold_cost=cost(threshold_indices);
    threshold_entropy=entropy(threshold_indices);
    threshold_water=water(threshold_indices);
    threshold_chlorine=chlorine(threshold_indices);
    plot_indices=sample_normalized_arclength( ...
        cost,entropy,20,threshold_indices);
    retained_archive_indices=order(keep);
    fprintf('Sparse Pareto plot: %d points displayed, archive indices %s\n', ...
        numel(plot_indices),strjoin(string( ...
        retained_archive_indices(plot_indices)),','));
    cost=cost(plot_indices); entropy=entropy(plot_indices);
    water=water(plot_indices); chlorine=chlorine(plot_indices);
    assert(max(water)>=100-1e-9 && max(chlorine)>=100-1e-9, ...
        'The sparse scale expects a displayed 100%%-service design');
    water_low=min(water);
    chlorine_low=min(chlorine);
    chlorine_high=max(chlorine);
    assert(water_low<100 && chlorine_low<chlorine_high, ...
        'The sparse service scales need distinct observed extremes');
    % SizeData is marker area in points squared. A low residual-service
    % percentage receives the largest circle; 100% receives the smallest.
    marker_area=@(pct)36+132*(chlorine_high-pct)/(chlorine_high-chlorine_low);
    size_key_levels=[chlorine_low,chlorine_high];
else
    marker_area=@(pct)max(6,2.5*pct);
    size_key_levels=[25,50,100];
end
font_size=11; % Point size for every text element in the exported figure.
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 17.5 12.5]);
ax=axes(fig); hold(ax,'on');
plot(ax,cost,entropy,'-','Color',[0.55 0.55 0.55], ...
    'LineWidth',0.9,'HandleVisibility','off');
scatter(ax,cost,entropy,marker_area(chlorine),water,'filled', ...
    'MarkerEdgeColor',[0.15 0.15 0.15], ...
    'LineWidth',0.45,'HandleVisibility','off');
if style=="tt_inverse_cl"
    red_yellow_green=interp1([0 0.5 1], ...
        [0.76 0.13 0.12; 0.98 0.78 0.20; 0.08 0.55 0.25], ...
        linspace(0,1,256)');
    colormap(ax,red_yellow_green);
    clim(ax,[water_low 100]);
else
    colormap(ax,turbo(256));clim(ax,[0 100]);
end
cb=colorbar(ax);
cb.Label.String='Worst water service [%]';
cb.FontName='Times New Roman';cb.FontSize=font_size;
cb.Label.FontSize=font_size;
if style=="tt_inverse_cl"
    % Lock the service scale: low service is red at the bottom, and 100%%
    % is green at the top in PNG, PDF, and SVG exports.
    cb.Limits=[water_low 100];
    cb.Direction='normal';
    cb.Ticks=[water_low 75 85 100];
    cb.TickLabels={sprintf('%.1f',water_low),'75','85','100'};
end
xlabel(ax,'Cost [10^6 relative units]');
ylabel(ax,'Branch-hop entropy [nat]');
ax.FontName='Times New Roman'; ax.FontSize=font_size;
ax.XLabel.FontSize=font_size; ax.YLabel.FontSize=font_size;
ax.LineWidth=0.8; grid(ax,'on'); box(ax,'on');
span=max(cost)-min(cost);
if span<=eps,span=1;end
xlim(ax,[min(cost)-0.04*span,max(cost)+0.04*span]);
span=max(entropy)-min(entropy);
if span<=eps,span=1;end
ylim(ax,[min(entropy)-0.06*span,max(entropy)+0.08*span]);
% A separate size key preserves the exact scatter areas. MATLAB's built-in
% legend makes all scatter icons the same size even when SizeData differs.
ax.Units='normalized';
cb.Units='normalized';
if style=="tt_inverse_cl"
    ax.Position=[0.11 0.16 0.68 0.78];
    cb.Position=[0.82 0.16 0.025 0.78];
    axis_x=xlim(ax);axis_y=ylim(ax);
    callout_x=0.60; % Three-line callouts end just inside the plot border.
    for t=1:numel(thresholds)
        tip_x=ax.Position(1)+ax.Position(3)* ...
            (threshold_cost(t)-axis_x(1))/diff(axis_x);
        tip_y=ax.Position(2)+ax.Position(4)* ...
            (threshold_entropy(t)-axis_y(1))/diff(axis_y);
        if isempty(callout_centers)
            if thresholds(t)==75
                box_position=[callout_x 0.57 0.18 0.125];
            else
                box_position=[callout_x 0.73 0.18 0.125];
            end
        else
            % The requested location is the midpoint of the label box's
            % left edge, specified in the plot's cost--entropy coordinates.
            point=callout_centers(t,:);
            left=ax.Position(1)+ax.Position(3)* ...
                (point(1)-axis_x(1))/diff(axis_x);
            middle=ax.Position(2)+ax.Position(4)* ...
                (point(2)-axis_y(1))/diff(axis_y);
            box_position=[left middle-0.125/2 0.17 0.125];
            assert(box_position(1)>=ax.Position(1) && ...
                box_position(1)+box_position(3)<= ...
                    ax.Position(1)+ax.Position(3) && ...
                box_position(2)>=ax.Position(2) && ...
                box_position(2)+box_position(4)<= ...
                    ax.Position(2)+ax.Position(4), ...
                'Requested callout box does not fit inside the data axes');
        end
        % Begin just left of the callout's vertical midpoint, so the
        % leader is visually attached to its own three-line label.
        tail=[box_position(1)-0.012, ...
            box_position(2)+box_position(4)/2];
        annotation(fig,'arrow',[tail(1) tip_x],[tail(2) tip_y], ...
            'Color',[0.15 0.15 0.15],'LineWidth',1.1, ...
            'HeadLength',8,'HeadWidth',8);
        annotation(fig,'textbox',box_position, ...
            'String',{sprintf('Both >%d%%',thresholds(t)), ...
            sprintf('w.w.: %.1f%%',threshold_water(t)), ...
            sprintf('Cl.w.: %.1f%%',threshold_chlorine(t))}, ...
            'EdgeColor','none','BackgroundColor','w','Margin',1, ...
            'HorizontalAlignment','left', ...
            'FontName','Times New Roman','FontSize',font_size);
    end
    % The lower-right corner of this front has no points. Keep the two
    % observed-size examples inside the plotting area, with a white backing
    % so that the grid does not run through their symbols or labels.
    key=axes(fig,'Units','normalized','Position',[0.48 0.19 0.28 0.15], ...
        'Color','w','Visible','off'); hold(key,'on');
    for k=1:2
        y=0.76-(k-1)*0.50;
        scatter(key,0.16,y,marker_area(size_key_levels(k)), ...
            [0.7 0.7 0.7],'filled','MarkerEdgeColor','k', ...
            'LineWidth',0.45);
        text(key,0.34,y,sprintf('Cl worst %.1f%%',size_key_levels(k)), ...
            'HorizontalAlignment','left','VerticalAlignment','middle', ...
            'FontName','Times New Roman','FontSize',font_size);
    end
    xlim(key,[0 1]);ylim(key,[0 1]);
else
    ax.Position=[0.11 0.24 0.68 0.70];
    cb.Position=[0.82 0.24 0.025 0.70];
    key=axes(fig,'Units','normalized','Position',[0.23 0.035 0.55 0.105], ...
        'Visible','off'); hold(key,'on');
    for k=1:numel(size_key_levels)
        scatter(key,k,0.71,marker_area(size_key_levels(k)), ...
            [0.7 0.7 0.7],'filled','MarkerEdgeColor','k', ...
            'LineWidth',0.45);
        text(key,k,0.11,sprintf('Cl worst %d%%',size_key_levels(k)), ...
            'HorizontalAlignment','center','FontName','Times New Roman', ...
            'FontSize',font_size);
    end
    xlim(key,[0.4 numel(size_key_levels)+0.6]);ylim(key,[0 1.2]);
end
[folder,name]=fileparts(output_file);
if ~isfolder(folder),mkdir(folder);end
exportgraphics(fig,output_file,'Resolution',450);
exportgraphics(fig,fullfile(folder,[name '.svg']), ...
    'ContentType','vector');
exportgraphics(fig,fullfile(folder,[name '.pdf']), ...
    'ContentType','vector');
close(fig);
end

function selected=sample_normalized_arclength( ...
        cost,entropy,target_count,required_indices)
% Greedily fill the largest gaps in normalized objective arclength using
% only existing designs. This avoids nearly coincident markers when the
% saved archive itself has an uneven gap near an endpoint.
n=numel(cost);
m=min(target_count,n);
if nargin<4,required_indices=[];end
if m==n,selected=(1:n)';return;end
x=(cost(:)-min(cost))/max(max(cost)-min(cost),eps);
y=(entropy(:)-min(entropy))/max(max(entropy)-min(entropy),eps);
distance=[0;cumsum(hypot(diff(x),diff(y)))];
if distance(end)<=eps
    distance=linspace(0,1,n)';
end
selected=unique([1;required_indices(:);n]);
assert(numel(selected)<=m,'Too many required Pareto display points');
while numel(selected)<m
    nearest_distance=min(abs(distance-distance(selected)'),[],2);
    nearest_distance(selected)=-inf;
    [~,next]=max(nearest_distance);
    selected(end+1,1)=next;
end
selected=sort(selected);
assert(all(diff(selected)>0) && selected(1)==1 && selected(end)==n, ...
    'Pareto arclength selection lost an endpoint or reused a point');
end
