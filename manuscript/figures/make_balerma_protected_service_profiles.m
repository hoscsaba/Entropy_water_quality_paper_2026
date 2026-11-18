function output_files=make_balerma_protected_service_profiles( ...
        paper_root,result_dir,figure_dir)
%MAKE_BALERMA_PROTECTED_SERVICE_PROFILES Plot full outage distributions.
% Reads previously saved PDA results; no hydraulic or chlorine solve runs.
% The same 448 eligible pipes are tested for every design in each state.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','balerma');
if nargin<2 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_sourceentry_v4');
end
if nargin<3 || isempty(figure_dir)
    figure_dir=fullfile(network_dir, ...
        'figures_staci_uniform_0p1_64in_sourceentry_v4');
end
cases=readtable(fullfile(result_dir,'protected_connector_stress', ...
    'pda_service_scenarios.csv'),'TextType','string');
assert(height(cases)==6*2*448 && all(~cases.Nonconvergent));
states=["all_four","R44_unavailable"];
state_titles={'All four reservoirs','R44 unavailable'};
objectives=["cost","hydraulic_entropy", ...
    "branch_hop_weighted_entropy","chlorine_entropy","todini"];
labels={'Cost = Cl concentration','Flow entropy', ...
    'Branch-hop entropy','Cl entropy','Todini'};
colors=[0.13 0.13 0.13;0.12 0.39 0.77; ...
    0.04 0.52 0.43;0.69 0.23 0.62;0.87 0.43 0.05];
styles={'-','-','--',':','-.'};
fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 19 11.5]);
layout=tiledlayout(fig,1,2,'TileSpacing','compact', ...
    'Padding','compact');
handles=gobjects(numel(objectives),1);
for s=1:numel(states)
    ax=nexttile(layout);hold(ax,'on');
    state=states(s);
    reference=cases(string(cases.Objective)=="cost" & ...
        string(cases.ReservoirAvailability)==state,:);
    assert(height(reference)==448);
    ids=sort(string(reference.FailedLinkID));
    x=100*(0:447)/447;
    for j=1:numel(objectives)
        subset=cases(string(cases.Objective)==objectives(j) & ...
            string(cases.ReservoirAvailability)==state,:);
        assert(height(subset)==448 && ...
            isequal(sort(string(subset.FailedLinkID)),ids));
        service=sort(100*double(subset.DeliveredDemandFraction));
        h=plot(ax,x,service,'Color',colors(j,:), ...
            'LineStyle',styles{j},'LineWidth',1.55, ...
            'DisplayName',labels{j});
        if s==1,handles(j)=h;end
    end
    chlorine_design=cases( ...
        string(cases.Objective)=="chlorine_concentration" & ...
        string(cases.ReservoirAvailability)==state,:);
    [~,a]=sort(string(reference.FailedLinkID));
    [~,b]=sort(string(chlorine_design.FailedLinkID));
    assert(isequal(double(reference.DeliveredDemandFraction(a)), ...
        double(chlorine_design.DeliveredDemandFraction(b))), ...
        'Cost and Cl-concentration design service no longer coincide');
    xlim(ax,[0 100]);ylim(ax,[60 100]);
    xticks(ax,0:20:100);yticks(ax,60:10:100);
    ax.FontSize=11;ax.LineWidth=0.8;
    ax.GridColor=[0.83 0.83 0.83];ax.GridAlpha=0.6;
    grid(ax,'on');box(ax,'on');
    title(ax,state_titles{s},'FontSize',11,'FontWeight','normal');
end
xlabel(layout,'Outage rank, worst to best [%]','FontSize',11);
ylabel(layout,'Delivered demand [%]','FontSize',11);
lgd=legend(handles,labels,'Orientation','horizontal', ...
    'NumColumns',3,'FontSize',11);
lgd.Layout.Tile='south';
if ~isfolder(figure_dir),mkdir(figure_dir);end
base=fullfile(figure_dir,'balerma_protected_failure_service_profiles');
output_files={[base '.png'],[base '.svg'],[base '.pdf']};
exportgraphics(fig,output_files{1},'Resolution',450);
exportgraphics(fig,output_files{2},'ContentType','vector');
exportgraphics(fig,output_files{3},'ContentType','vector');
close(fig);
end
