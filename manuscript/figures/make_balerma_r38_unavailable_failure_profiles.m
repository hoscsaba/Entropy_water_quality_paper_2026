function files=make_balerma_r38_unavailable_failure_profiles( ...
        paper_root,result_dir,figure_dir)
%MAKE_BALERMA_R38_UNAVAILABLE_FAILURE_PROFILES Plot saved PDA cases only.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','balerma');
if nargin<2 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
end
if nargin<3 || isempty(figure_dir)
    figure_dir=fullfile(network_dir,'figures_staci_r38_anchor_v1');
end
T=readtable(fullfile(result_dir,'r38_unavailable_protected','cases.csv'), ...
    'TextType','string');
names=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
labels={"Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"};
styles={'-','-','-','--',':','-.'};
colors=lines(6);
assert(height(T)==6*448);
fig=figure('Color','w','Units','centimeters','Position',[2 2 18 11]);
ax=axes(fig);hold(ax,'on');
minimum_service=100;
x=100*((1:448)'-1)/447;
profiles=zeros(448,6);
for k=1:6
    rows=T(T.Objective==names(k),:);
    assert(height(rows)==448 && all(~rows.Nonconvergent));
    water=sort(100*double(rows.DeliveredDemandFraction));
    profiles(:,k)=water;
    minimum_service=min(minimum_service,water(1));
    plot(ax,x,water,styles{k},'Color',colors(k,:), ...
        'LineWidth',1.3,'DisplayName',labels{k});
end
xlabel(ax,'Pipe-failure cases, sorted within each design (%)');
ylabel(ax,'Delivered demand (%)');
xlim(ax,[0 100]);
ylim(ax,[max(0,5*floor((minimum_service-2)/5)) 101]);
ax.FontSize=11;ax.LineWidth=0.8;grid(ax,'on');box(ax,'on');
legend(ax,'Location','southoutside','NumColumns',3,'FontSize',10.5);
drawnow; % The outside legend establishes the final main-axes position.
main_position=ax.Position;
% The lower-right region of the main graph contains no service curves.
% Place a 0--10% detail there, entirely inside the main axes frame.
inset_fraction=[0.50 0.25 0.44 0.44];
inset_position=[main_position(1:2)+ ...
    inset_fraction(1:2).*main_position(3:4), ...
    inset_fraction(3:4).*main_position(3:4)];
covered_x=100*[inset_fraction(1), ...
    inset_fraction(1)+inset_fraction(3)];
y_base=ylim(ax);
covered_y_top=y_base(1)+(inset_fraction(2)+inset_fraction(4))* ...
    diff(y_base);
assert(min(profiles(x>=covered_x(1) & x<=covered_x(2),:), ...
    [],'all')>covered_y_top+5, ...
    'The detail inset would obscure a service curve');
detail=axes('Parent',fig,'Units','normalized', ...
    'Position',inset_position,'Color','w');
hold(detail,'on');
for k=1:6
    plot(detail,x,profiles(:,k),styles{k}, ...
        'Color',colors(k,:),'LineWidth',1.1, ...
        'HandleVisibility','off');
end
xlim(detail,[0 10]);ylim(detail,y_base);
detail.XTick=[0 5 10];detail.YTick=[40 60 80 100];
detail.FontSize=9.5;detail.LineWidth=0.8;
grid(detail,'on');box(detail,'on');
title(detail,'First 10% of cases','FontSize',10.5, ...
    'FontWeight','normal');
ylabel(detail,'Delivered (%)','FontSize',9.5);
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir, ...
    'balerma_r38_unavailable_protected_failure_profiles');
files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,files{1},'Resolution',350);
exportgraphics(fig,files{2},'ContentType','vector');
exportgraphics(fig,files{3},'ContentType','vector');
close(fig);
end
