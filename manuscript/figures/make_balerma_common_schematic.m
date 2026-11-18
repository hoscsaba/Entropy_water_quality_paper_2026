function output_files=make_balerma_common_schematic(output_dir)
%MAKE_BALERMA_COMMON_SCHEMATIC Original topology with four labeled supplies.
% This is a plotting-only function; no hydraulic or optimization solve runs.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root,'-begin');
network_dir=fullfile(root,'networks','balerma');
addpath(network_dir,'-begin');
cfg=network_config(network_dir);
wdn.setup_toolkit(cfg);
[d,~]=wdn.open_network(cfg);
release=onCleanup(@()d.unload);
coordinates=d.getNodeCoordinates();
x=cell2mat(coordinates(:,1));
y=cell2mat(coordinates(:,2));
links=double(d.getLinkNodesIndex);
types=double(d.getNodeTypeIndex);
ids=string(d.getNodeNameID);
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 17.5 20]);
ax=axes(fig,'Position',[0.03 0.03 0.94 0.94]);hold(ax,'on');
for k=1:size(links,1)
    plot(ax,x(links(k,:)),y(links(k,:)),'-', ...
        'Color',[0.35 0.35 0.35],'LineWidth',0.48);
end
scatter(ax,x,y,6,[0.12 0.12 0.12],'filled');
reservoirs=find(types==1);
assert(numel(reservoirs)==4 && ...
    all(ismember(["38","43","44","88"],ids(reservoirs))), ...
    'The Balerma schematic requires four original reservoirs');
scatter(ax,x(reservoirs),y(reservoirs),62,[0.10 0.32 0.80], ...
    's','filled','MarkerEdgeColor','k','LineWidth',0.8);
span_x=max(x)-min(x);span_y=max(y)-min(y);
dx=0.014*span_x;dy=0.018*span_y;
for index=reservoirs(:)'
    label_x=x(index)+dx;
    horizontal_alignment='left';
    if ismember(ids(index),["38","44"])
        label_x=x(index)-dx;
        horizontal_alignment='right';
    end
    text(ax,label_x,y(index)+dy,"R"+ids(index), ...
        'FontSize',14.5,'FontWeight','normal','Color',[0 0 0], ...
        'BackgroundColor','w','Margin',1, ...
        'HorizontalAlignment',horizontal_alignment, ...
        'VerticalAlignment','bottom');
end
axis(ax,'equal');axis(ax,'off');
xlim(ax,[min(x)-0.035*span_x,max(x)+0.05*span_x]);
ylim(ax,[min(y)-0.035*span_y,max(y)+0.05*span_y]);
if nargin<1 || isempty(output_dir)
    output_dir=fullfile(network_dir, ...
        'figures_staci_uniform_0p1_64in_staging');
end
if ~isfolder(output_dir),mkdir(output_dir);end
base=fullfile(output_dir,'balerma_common_schematic');
output_files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,output_files{1},'Resolution',450);
exportgraphics(fig,output_files{2},'ContentType','vector');
exportgraphics(fig,output_files{3},'ContentType','vector');
close(fig);
clear release
end
