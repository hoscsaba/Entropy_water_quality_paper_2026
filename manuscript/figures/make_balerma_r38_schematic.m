function files=make_balerma_r38_schematic(paper_root,figure_dir)
%MAKE_BALERMA_R38_SCHEMATIC Map the nominal R38-anchor source state.
% The geometry is read from the unchanged four-reservoir benchmark INP.
% R38 is drawn as a pressure anchor, while R43/R44/R88 remain physical
% fixed-head reservoirs during nominal optimization. No solve is run.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','balerma');
if nargin<2 || isempty(figure_dir)
    figure_dir=fullfile(network_dir,'figures_staci_r38_anchor_v1');
end
addpath(paper_root,network_dir);
cfg=network_config_r38_anchor(network_dir);
cfg.inp_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
wdn.setup_toolkit(cfg);
[d,~]=wdn.open_network(cfg);
release=onCleanup(@()d.unload()); %#ok<NASGU>
coordinates=d.getNodeCoordinates();
x=cell2mat(coordinates(:,1));
y=cell2mat(coordinates(:,2));
xy=[x(:),y(:)];
nodes=double(d.getLinkNodesIndex());
ids=string(d.getNodeNameID());
width=max(xy(:,1))-min(xy(:,1));
height=max(xy(:,2))-min(xy(:,2));
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 14 18]);
ax=axes(fig);hold(ax,'on');
for k=1:size(nodes,1)
    plot(ax,xy(nodes(k,:),1),xy(nodes(k,:),2), ...
        'Color',[0.35 0.35 0.35],'LineWidth',0.45);
end
scatter(ax,xy(:,1),xy(:,2),4,[0.10 0.10 0.10],'filled');
for id=["43","44","88"]
    i=find(ids==id,1);
    assert(isscalar(i),'Missing Balerma source R%s',id);
    scatter(ax,xy(i,1),xy(i,2),65,[0.10 0.28 0.75], ...
        's','filled','MarkerEdgeColor','k','LineWidth',0.65);
end
i=find(ids=="38",1);
assert(isscalar(i),'Missing Balerma R38 anchor');
scatter(ax,xy(i,1),xy(i,2),65,[0.55 0.22 0.62], ...
    'd','filled','MarkerEdgeColor','k','LineWidth',0.65);
labels={"38",[-0.017 0.020];"43",[-0.008 0.020]; ...
    "44",[-0.012 0.025];"88",[-0.012 0.022]};
for k=1:size(labels,1)
    j=find(ids==labels{k,1},1);
    offset=labels{k,2};
    text(ax,xy(j,1)+offset(1)*width, ...
        xy(j,2)+offset(2)*height,'R'+labels{k,1}, ...
        'FontSize',9,'Color','k','Interpreter','none', ...
        'HorizontalAlignment','right','BackgroundColor','w', ...
        'Margin',1);
end
axis(ax,'equal');axis(ax,'off');
xlim(ax,[min(xy(:,1))-0.075*width,max(xy(:,1))+0.065*width]);
ylim(ax,[min(xy(:,2))-0.025*height,max(xy(:,2))+0.060*height]);
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir,'balerma_r38_anchor_schematic');
files={[base '.png'],[base '.svg']};
exportgraphics(fig,files{1},'Resolution',350);
exportgraphics(fig,files{2},'ContentType','vector');
close(fig);
end
