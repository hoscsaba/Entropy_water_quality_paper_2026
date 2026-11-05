function plot_two_consumer_pair(diameter, flow, head, chlorine, demands, metric, metric_name, node_entropy, output_prefix)
%PLOT_TWO_CONSUMER_PAIR Two wide panels with data placed beside each node.
% Rows A/B; pipe columns P0--P3; node columns S,J,D1,D2. Local entropy
% contributions come directly from the STACI-based example calculation. Pass [] for chlorine
% in the hydraulic-only figure. Each export is produced as PNG and SVG.
assert(isequal(size(node_entropy),[2 4]));
fig=figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[2 2 35 12.5]);
t=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
xy=[0 0;2.7 0;6.3 1.8;6.3 -1.8];
link_ends=[1 2;2 3;2 4;3 4];
for k=1:2
 ax=nexttile(t);hold(ax,'on');
 for j=1:4
  pt=xy(link_ends(j,:),:);
  plot(ax,pt(:,1),pt(:,2),'k-', ...
      'LineWidth',min(5,1.2+0.015*diameter(k,j)));
 end
 % Indicate cross-link flow and withdrawals from the two consumer nodes.
 quiver(ax,6.14,0.45,0,-0.70*sign(flow(k,4)),0,'Color','k', ...
     'LineWidth',1.35,'MaxHeadSize',0.8);
 for n=3:4
  quiver(ax,6.51,xy(n,2),0.40,0,0,'Color','k', ...
      'LineWidth',1.3,'MaxHeadSize',0.8);
 end
 scatter(ax,xy(:,1),xy(:,2),92,'w','filled', ...
     'MarkerEdgeColor','k','LineWidth',1.35);
 % Node names remain adjacent to their symbols.
 text(ax,0,-0.32,'$S$','Interpreter','latex','FontSize',16, ...
     'HorizontalAlignment','center');
 text(ax,2.7,-0.32,'$J$','Interpreter','latex','FontSize',16, ...
     'HorizontalAlignment','center');
 text(ax,6.3,2.14,'$D_1$','Interpreter','latex','FontSize',16, ...
     'HorizontalAlignment','center');
 text(ax,6.3,-2.14,'$D_2$','Interpreter','latex','FontSize',16, ...
     'HorizontalAlignment','center');
 % Diameter and flow labels have a 0.42-unit vertical separation.
 label_pipe(ax,1.35,1.03,0.61,0,diameter(k,1),flow(k,1),'center');
 label_pipe(ax,4.33,2.55,2.13,1,diameter(k,2),flow(k,2),'center');
 label_pipe(ax,4.25,-2.48,-2.90,2,diameter(k,3),flow(k,3),'center');
 label_pipe(ax,6.55,0.32,-0.10,3,diameter(k,4),abs(flow(k,4)),'left');
 % The two non-consuming nodes have no withdrawal line. All values remain
 % beside their own node, with no detached legend or inset boxes.
 node_data(ax,-0.10,-0.64,head(k,1),[],node_entropy(k,1),chlorine,k,1);
 node_data(ax,2.40,-1.08,head(k,2),[],node_entropy(k,2),chlorine,k,2);
 node_data(ax,7.05,2.32,head(k,3),demands(1),node_entropy(k,3),chlorine,k,3);
 node_data(ax,7.05,-0.85,head(k,4),demands(2),node_entropy(k,4),chlorine,k,4);
 title(ax,sprintf('(%c) Design %c: $%s=%s$ nat', ...
     'a'+k-1,'A'+k-1,metric_name,fmt_num(metric(k),5)), ...
     'Interpreter','latex','FontSize',18,'FontWeight','normal');
 xlim(ax,[-0.72 12.25]);ylim(ax,[-3.42 3.03]);axis(ax,'off');
end
exportgraphics(fig,[output_prefix '.png'],'Resolution',600);
exportgraphics(fig,[output_prefix '.svg'],'ContentType','vector');
close(fig);
end

function node_data(ax,x,y,head,demand,entropy,chlorine,k,n)
lines={};
if ~isempty(demand)
 lines{end+1}=sprintf('$q_{\\mathrm{use}}=%s$ L/s',fmt_num(demand,1));
end
lines{end+1}=sprintf('$H=%s$ m',fmt_num(head,2));
if ~isempty(chlorine)
 lines{end+1}=sprintf('$c=%s$ mg/L',fmt_num(chlorine(k,n),3));
end
lines{end+1}=sprintf('$S_i=%s$ nat',fmt_num(entropy,5));
text(ax,x,y,lines,'Interpreter','latex','FontSize',15, ...
    'HorizontalAlignment','left','VerticalAlignment','top', ...
    'Color',[0.08 0.08 0.08]);
end

function label_pipe(ax,x,yd,yq,j,d,q,alignment)
text(ax,x,yd,sprintf('$d_%d=%s$ mm',j,fmt_num(d,1)), ...
    'Interpreter','latex','FontSize',16,'HorizontalAlignment',alignment);
text(ax,x,yq,sprintf('$Q_%d=%s$ L/s',j,fmt_num(q,2)), ...
    'Interpreter','latex','FontSize',16,'HorizontalAlignment',alignment);
end

function s=fmt_num(x,decimals)
s=sprintf(['%.' num2str(decimals) 'f'],x);
if contains(s,'.')
 s=regexprep(s,'0+$','');
 s=regexprep(s,'\.$','');
end
if strcmp(s,'-0'),s='0';end
end
