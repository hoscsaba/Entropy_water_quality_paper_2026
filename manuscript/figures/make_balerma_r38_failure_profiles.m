function files=make_balerma_r38_failure_profiles(paper_root,result_dir,figure_dir)
%MAKE_BALERMA_R38_FAILURE_PROFILES Plot saved all-four-reservoir PDA cases.
% Reads only the six-by-448 case CSV; no hydraulic or quality solve.
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
T=readtable(fullfile(result_dir, ...
    'pda_four_reservoir_protected_cases.csv'),'TextType','string');
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
for k=1:6
    rows=T(T.Objective==names(k),:);
    assert(height(rows)==448 && all(~rows.Nonconvergent));
    water=sort(100*double(rows.DeliveredDemandFraction));
    minimum_service=min(minimum_service,water(1));
    x=100*((1:448)'-1)/447;
    plot(ax,x,water,styles{k},'Color',colors(k,:), ...
        'LineWidth',1.3,'DisplayName',labels{k});
end
xlabel(ax,'Pipe-failure cases, sorted within each design (%)');
ylabel(ax,'Delivered demand (%)');
xlim(ax,[0 100]);
ylim(ax,[max(0,5*floor((minimum_service-2)/5)) 101]);
ax.FontSize=11;ax.LineWidth=0.8;grid(ax,'on');box(ax,'on');
legend(ax,'Location','southoutside','NumColumns',3,'FontSize',10.5);
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir,'balerma_r38_protected_failure_profiles');
files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,files{1},'Resolution',350);
exportgraphics(fig,files{2},'ContentType','vector');
exportgraphics(fig,files{3},'ContentType','vector');
close(fig);
end
