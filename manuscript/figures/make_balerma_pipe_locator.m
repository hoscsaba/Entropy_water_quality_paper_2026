function output_files=make_balerma_pipe_locator(pipe_id,output_dir)
%MAKE_BALERMA_PIPE_LOCATOR Show P251 or P338 on the original Balerma map.
% No hydraulic, water-quality, or optimization calculation is performed.
if nargin<1 || isempty(pipe_id),pipe_id="251";end
pipe_id=erase(string(pipe_id),"P");
assert(ismember(pipe_id,["251","338"]), ...
    'The locator currently supports P251 and P338');
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir=fullfile(root,'networks','balerma');
addpath(root,network_dir);
cfg=network_config(network_dir);
wdn.setup_toolkit(cfg);
[d,model]=wdn.open_network(cfg);
release=onCleanup(@()d.unload);
coordinates=d.getNodeCoordinates();
x=cell2mat(coordinates(:,1));y=cell2mat(coordinates(:,2));
links=double(d.getLinkNodesIndex);
node_ids=string(d.getNodeNameID);
link_ids=string(model.link_ids(:));
assert(numel(link_ids)==size(links,1),'Link-order mismatch');
idx251=find(link_ids=="251");idx338=find(link_ids=="338");
idx5=find(link_ids=="5");
r38=find(node_ids=="38");n202001=find(node_ids=="202001");
n215001=find(node_ids=="215001");n266=find(node_ids=="266");
assert(isscalar(idx251) && isscalar(idx338) && isscalar(idx5) && ...
    isscalar(r38) && isscalar(n202001) && isscalar(n215001) && ...
    isscalar(n266) && ...
    isequal(sort(links(idx251,:)),sort([n215001,n202001])) && ...
    isequal(sort(links(idx338,:)),sort([n202001,r38])) && ...
    isequal(sort(links(idx5,:)),sort([n266,r38])), ...
    'Original Balerma pipe endpoints changed');
if pipe_id=="251"
    target=idx251;context=idx338;
    context_name='P338';
else
    target=idx338;context=idx5;
    context_name='P5';
end
target_name=['P' char(pipe_id)];
red=[0.79 0.09 0.13];blue=[0.08 0.39 0.76];
fig=figure('Color','w','Units','centimeters','Position',[2 2 19 14.5]);
full_ax=axes(fig,'Position',[0.02 0.10 0.53 0.81]);
draw_map(full_ax,x,y,links,target,context,red,blue);
span_x=max(x)-min(x);span_y=max(y)-min(y);
xlim(full_ax,[min(x)-0.04*span_x,max(x)+0.04*span_x]);
ylim(full_ax,[min(y)-0.04*span_y,max(y)+0.04*span_y]);
mid_x=mean(x(links(target,:)));mid_y=mean(y(links(target,:)));
plot(full_ax,mid_x,mid_y,'o','MarkerSize',16, ...
    'MarkerEdgeColor',red,'MarkerFaceColor','none','LineWidth',1.4);
text(full_ax,x(r38)-17,y(r38)-24,'R38', ...
    'Color',[0 0 0],'FontSize',11,'FontWeight','bold', ...
    'BackgroundColor','w','Margin',1, ...
    'HorizontalAlignment','right');
title(full_ax,'Balerma network','FontWeight','normal','FontSize',11);

zoom_ax=axes(fig,'Position',[0.59 0.15 0.37 0.71]);
draw_map(zoom_ax,x,y,links,target,context,red,blue);
xlim(zoom_ax,[0 120]);ylim(zoom_ax,[360 550]);
plot(zoom_ax,x(r38),y(r38),'s','MarkerSize',9, ...
    'MarkerFaceColor',[0.10 0.32 0.80], ...
    'MarkerEdgeColor','k','LineWidth',0.8);
plot(zoom_ax,x(n202001),y(n202001),'ko', ...
    'MarkerFaceColor','k','MarkerSize',4);
plot(zoom_ax,x(n215001),y(n215001),'ko', ...
    'MarkerFaceColor','k','MarkerSize',4);
text(zoom_ax,72,481,'R38','FontSize',11,'FontWeight','bold', ...
    'BackgroundColor','w','Margin',1);
if pipe_id=="251"
    text(zoom_ax,65,460,'P338','Color',blue,'FontSize',11, ...
        'FontWeight','bold','BackgroundColor','w','Margin',1);
    text(zoom_ax,64,416,'P251','Color',red,'FontSize',11, ...
        'FontWeight','bold','BackgroundColor','w','Margin',1);
    text(zoom_ax,18,445,'202001','FontSize',10, ...
        'BackgroundColor','w','Margin',1);
    text(zoom_ax,10,394,'215001','FontSize',10, ...
        'BackgroundColor','w','Margin',1);
else
    text(zoom_ax,67,457,'P338','Color',red,'FontSize',11, ...
        'FontWeight','bold','BackgroundColor','w','Margin',1);
    text(zoom_ax,67,507,'P5','Color',blue,'FontSize',11, ...
        'FontWeight','bold','BackgroundColor','w','Margin',1);
    text(zoom_ax,18,425,'202001','FontSize',10, ...
        'BackgroundColor','w','Margin',1);
    text(zoom_ax,18,530,'266','FontSize',10, ...
        'BackgroundColor','w','Margin',1);
end
title(zoom_ax,'R38 neighbourhood','FontWeight','normal','FontSize',11);
annotation(fig,'textbox',[0.59 0.025 0.37 0.06], ...
    'String',['Red: ' target_name '   Blue: ' context_name], ...
    'FontSize',11,'EdgeColor','none', ...
    'HorizontalAlignment','center');
if nargin<2 || isempty(output_dir)
    output_dir=fullfile(network_dir, ...
        'figures_staci_uniform_0p1_64in_sourceentry_v4');
end
if ~isfolder(output_dir),mkdir(output_dir);end
base=fullfile(output_dir, ...
    ['balerma_p' char(pipe_id) '_locator']);
output_files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,output_files{1},'Resolution',400);
exportgraphics(fig,output_files{2},'ContentType','vector');
exportgraphics(fig,output_files{3},'ContentType','vector');
close(fig);
clear release
end

function draw_map(ax,x,y,links,target,context,red,blue)
hold(ax,'on');
for k=1:size(links,1)
    plot(ax,x(links(k,:)),y(links(k,:)),'-', ...
        'Color',[0.70 0.72 0.75],'LineWidth',0.5);
end
plot(ax,x(links(context,:)),y(links(context,:)),'-', ...
    'Color',blue,'LineWidth',2.4);
plot(ax,x(links(target,:)),y(links(target,:)),'-', ...
    'Color',red,'LineWidth',3.4);
axis(ax,'equal');axis(ax,'off');
end
