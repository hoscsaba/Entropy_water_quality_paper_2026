function make_pressure_anchor_mwe_figure
%MAKE_PRESSURE_ANCHOR_MWE_FIGURE Signed-flow pressure-boundary example.
% Consumer D always receives one flow unit. Positive x means basin charging:
% S supplies 1+x, J sends 1 to D and x to B. Negative x means basin supply:
% S supplies 1+x, B supplies -x, and J sends 1 to D (-1 <= x <= 0).
% When B is wrongly counted as a service branch/source, the right panel
% displays junction split entropy for x >= 0 and source-share entropy for
% x <= 0. This is analytic; no EPANET simulation or optimization is used.
% Exports pressure_anchor_mwe.png and pressure_anchor_mwe.svg.

root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
output_dir=fullfile(root,'manuscript','generated','figures');
if ~isfolder(output_dir),mkdir(output_dir);end

x_supply=linspace(-1,0,401);
x_charge=linspace(0,1,401);
% Two external-source probabilities for x < 0; J has one outgoing branch.
s_supply=-zlogz(1+x_supply)-zlogz(-x_supply);
% One external source for x > 0; J has two outgoing branches.
p_D=1./(1+x_charge);p_B=x_charge./(1+x_charge);
s_charge=-zlogz(p_D)-zlogz(p_B);
assert(abs(s_supply(1))<1e-12 && abs(s_supply(end))<1e-12);
assert(abs(s_supply(201)-log(2))<1e-12);
assert(abs(s_charge(1))<1e-12 && abs(s_charge(end)-log(2))<1e-12);
assert(all(diff(s_supply(1:201))>=-1e-12) && ...
    all(diff(s_supply(201:end))<=1e-12) && ...
    all(diff(s_charge)>=-1e-12));

red=[0.72 0.18 0.13];blue=[0.18 0.40 0.67];
fig=figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[2 2 18 8.6]);
t=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

ax1=nexttile(t);hold(ax1,'on');
S=[0 0];J=[1.20 0];D=[2.45 0.74];B=[2.45 -0.74];
plot(ax1,[S(1) J(1)],[S(2) J(2)],'k-','LineWidth',2.0);
plot(ax1,[J(1) D(1)],[J(2) D(2)],'k-','LineWidth',2.0);
plot(ax1,[J(1) B(1)],[J(2) B(2)],'-','Color',red,'LineWidth',2.2);
% Arrow on the red pipe defines the positive (charging) direction J -> B.
quiver(ax1,1.75,-0.326,0.32,-0.189,0,'Color',red, ...
    'LineWidth',2.0,'MaxHeadSize',1.6);
scatter(ax1,[S(1) J(1) D(1)],[S(2) J(2) D(2)],75,'w','filled', ...
    'MarkerEdgeColor','k','LineWidth',1.2);
rectangle(ax1,'Position',[B(1)-0.12 B(2)-0.12 0.24 0.24], ...
    'FaceColor',[0.78 0.89 0.98],'EdgeColor',[0.12 0.35 0.63], ...
    'LineWidth',1.2);
text(ax1,S(1),-0.26,'$S$','Interpreter','latex','FontSize',12, ...
    'HorizontalAlignment','center');
text(ax1,J(1),0.25,'$J$','Interpreter','latex','FontSize',12, ...
    'HorizontalAlignment','center');
text(ax1,D(1),0.98,'$D$','Interpreter','latex','FontSize',12, ...
    'HorizontalAlignment','center');
text(ax1,B(1),-1.00,'$B$','Interpreter','latex','FontSize',12, ...
    'HorizontalAlignment','center');
text(ax1,0.58,0.14,'$1+x$','Interpreter','latex','FontSize',12, ...
    'HorizontalAlignment','center');
text(ax1,1.82,0.59,'$1$','Interpreter','latex','FontSize',12, ...
    'HorizontalAlignment','center');
text(ax1,1.81,-0.68,'$x$','Interpreter','latex','FontSize',12, ...
    'Color',red,'HorizontalAlignment','center');
axis(ax1,'equal');xlim(ax1,[-0.30 2.84]);ylim(ax1,[-1.18 1.17]);
axis(ax1,'off');
title(ax1,'(a) Signed basin flow','FontName','Times New Roman', ...
    'FontWeight','normal','FontSize',13);

ax2=nexttile(t);hold(ax2,'on');
plot(ax2,x_supply,s_supply,'-','Color',blue,'LineWidth',2.0);
plot(ax2,x_charge,s_charge,'-','Color',red,'LineWidth',2.0);
plot(ax2,[0 0],[0 0.76],':','Color',[0.45 0.45 0.45], ...
    'LineWidth',0.9);
scatter(ax2,-0.5,log(2),35,blue,'filled');
scatter(ax2,1,log(2),35,red,'filled');
scatter(ax2,0,0,28,[0.2 0.2 0.2],'filled');
text(ax2,-0.93,0.775,'$B$ supplies','Interpreter','latex', ...
    'FontSize',11,'Color',blue);
text(ax2,0.19,0.775,'$B$ charges','Interpreter','latex', ...
    'FontSize',11,'Color',red);
xlabel(ax2,'signed basin flow $x$ (flow units)','Interpreter','latex', ...
    'FontSize',12);
ylabel(ax2,'$S_{\mathrm{counted}}$ (nat)','Interpreter','latex', ...
    'FontSize',12);
ax2.FontSize=11;ax2.TickLabelInterpreter='latex';ax2.LineWidth=0.8;
xticks(ax2,[-1 -0.5 0 0.5 1]);yticks(ax2,[0 0.2 0.4 0.6]);
xlim(ax2,[-1.03 1.03]);ylim(ax2,[-0.025 0.845]);
grid(ax2,'on');ax2.GridAlpha=0.12;box(ax2,'on');
title(ax2,'(b) Computed entropy','FontName','Times New Roman', ...
    'FontWeight','normal','FontSize',13);

exportgraphics(fig,fullfile(output_dir,'pressure_anchor_mwe.png'), ...
    'Resolution',600);
exportgraphics(fig,fullfile(output_dir,'pressure_anchor_mwe.svg'), ...
    'ContentType','vector');
close(fig);
end

function y=zlogz(p)
y=zeros(size(p));positive=p>0;
y(positive)=p(positive).*log(p(positive));
end
