function summary = make_tanyimboh_equal_entropy_pair()
%MAKE_TANYIMBOH_EQUAL_ENTROPY_PAIR Equal-flow and equal-chlorine-entropy TT pair.
% A is 0.92 times the archived best-known hydraulic-entropy diameter vector.
% B changes internal heads, then uses inverse Hazen-Williams sizing to hold
% every link flow fixed. One scalar root keeps total chlorine entropy fixed.
% STACI replays both designs; no new genetic optimization is performed.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir=fullfile(root,'networks','tanyimboh_templeman');
addpath(root,network_dir);
cfg=network_config(network_dir);
archived=load(fullfile(network_dir,'results_staci','hydraulic_entropy.mat'),'result');
base=double(archived.result.design_diameters(:));
pipe_ids=string(cfg.design_link_ids(:));
ends=["1","3";"2","4";"4","6";"3","5"; ...
      "1","4";"2","3";"5","6";"3","4"];
diameters=zeros(numel(pipe_ids),2);
diameters(:,1)=0.92*base;
st=StaciModel(fullfile(network_dir,'input','network_staci_fixed_load.inp'));
cleanup=onCleanup(@()st.release());
st.setLinkProperty(pipe_ids,'diameter_m',diameters(:,1)/1000);
initial_status=st.solveHydraulics();
assert(initial_status.converged,'STACI failed for reference design A');
initial_nodes=st.nodeResults();
node_ids=string(initial_nodes.id(:));
initial_heads=double(initial_nodes.total_head_m(:));
[found_a,a]=ismember(ends(:,1),node_ids);
[found_b,b]=ismember(ends(:,2),node_ids);
assert(all(found_a)&all(found_b),'Endpoint IDs missing');
initial_quality=st.solveSteadyQuality('chemical');
[found_q,qi]=ismember(node_ids,string(initial_quality.node_ids(:)));
assert(all(found_q),'Quality IDs missing');
initial_chlorine=1000*double(initial_quality.node_concentration_kgm3(qi));
target_chlorine_entropy=wdn.staci_chlorine_entropy(st,cfg,initial_chlorine);

% One free head shift is specified at node 3. The head at node 4 is then
% found by a scalar root. The fixed adapter P_input_2 carries 20 m3/h in
% both designs because total demand and node-2 injection are fixed.
head3_shift=-0.5;
head4_shift=fzero(@(z) chlorine_gap(z),[0,0.5], ...
    optimset('TolX',1e-11,'Display','off'));
target_heads=initial_heads;
target_heads(node_ids=="3")=target_heads(node_ids=="3")+head3_shift;
target_heads(node_ids=="4")=target_heads(node_ids=="4")+head4_shift;
diameters(:,2)=inverse_diameters(target_heads);
flow=zeros(numel(pipe_ids),2);
heads=zeros(numel(node_ids),2);
local_entropy=zeros(numel(node_ids),2);
local_chlorine_entropy=zeros(numel(node_ids),2);
chlorine=zeros(numel(node_ids),2);
entropy=zeros(1,2);
chlorine_entropy=zeros(1,2);
for k=1:2
    st.setLinkProperty(pipe_ids,'diameter_m',diameters(:,k)/1000);
    status=st.solveHydraulics();
    assert(status.converged,'STACI hydraulics failed for design %d',k);
    nodes=st.nodeResults(); links=st.linkResults();
    [found_li,li]=ismember(pipe_ids,string(links.id(:)));
    [found_ni,ni]=ismember(node_ids,string(nodes.id(:)));
    assert(all(found_li)&&all(found_ni),'STACI IDs changed between designs');
    flow(:,k)=double(links.flow_rate_m3s(li))*3600; % INP units: m3/h
    heads(:,k)=double(nodes.total_head_m(ni));
    [entropy(k),details]=wdn.staci_flow_entropy(st,cfg,[]);
    local_entropy(:,k)=details.node_entropy(ni);
    quality=st.solveSteadyQuality('chemical');
    [quality_found,quality_idx]=ismember(node_ids,string(quality.node_ids(:)));
    assert(all(quality_found),'Quality IDs changed between designs');
    chlorine(:,k)=1000*double(quality.node_concentration_kgm3(quality_idx));
    [chlorine_entropy(k),chlorine_details]= ...
        wdn.staci_chlorine_entropy(st,cfg,chlorine(:,k));
    local_chlorine_entropy(:,k)=chlorine_details.node_entropy(ni);
end
assert(all(diameters(:)>=cfg.minimum_diameter) && ...
    all(diameters(:)<=cfg.maximum_diameter),'Diameter bounds violated');
[found_consumer,consumer_idx]=ismember(string(cfg.pressure_node_ids(:)),node_ids);
assert(all(found_consumer),'Consumer nodes missing');
assert(all(heads(consumer_idx,:)>cfg.minimum_pressure,'all'), ...
    'Consumer head constraint violated');
assert(all(chlorine(consumer_idx,:)>0.2,'all'), ...
    'Consumer chlorine residual is below 0.2 mg/L');
max_flow_difference=max(abs(diff(flow,1,2)));
entropy_difference=abs(diff(entropy));
assert(max_flow_difference<1e-5,'Common-flow check failed');
assert(entropy_difference<1e-7,'Equal-entropy check failed');
chlorine_entropy_difference=abs(diff(chlorine_entropy));
assert(chlorine_entropy_difference<1e-8,'Equal chlorine-entropy check failed');

% Local entropy is the *conditional splitting* term; source mixing is common
% and does not affect which physical endpoints are locally nonzero.
positive=local_entropy(:,1)>1e-6 & local_entropy(:,2)>1e-6;
both_positive=positive(a)&positive(b);
changed=abs(diff(diameters,1,2))>0.005;
assert(nnz(changed&both_positive)==6, ...
    'Expected six changed pipes between positive-entropy nodes');

link_table=table(pipe_ids,ends(:,1),ends(:,2),diameters(:,1), ...
    diameters(:,2),flow(:,1),flow(:,2),changed,both_positive, ...
    'VariableNames',{'Pipe','From','To','DiameterA_mm','DiameterB_mm', ...
    'FlowA_m3h','FlowB_m3h','DiameterChanged', ...
    'BothEndpointsPositiveLocalEntropy'});
node_table=table(node_ids,heads(:,1),heads(:,2), ...
    chlorine(:,1),chlorine(:,2),local_entropy(:,1),local_entropy(:,2), ...
    local_chlorine_entropy(:,1),local_chlorine_entropy(:,2),positive, ...
    'VariableNames',{'Node','HeadA_m','HeadB_m', ...
    'ChlorineA_mgL','ChlorineB_mgL', ...
    'HydraulicLocalEntropyA_nat','HydraulicLocalEntropyB_nat', ...
    'ChlorineLocalEntropyA_nat','ChlorineLocalEntropyB_nat', ...
    'PositiveLocalEntropy'});
out_dir=fullfile(network_dir,'results_staci');
writetable(link_table,fullfile(out_dir,'equal_entropy_pair_links.csv'));
writetable(node_table,fullfile(out_dir,'equal_entropy_pair_nodes.csv'));
summary=table(["A";"B"],entropy(:),chlorine_entropy(:), ...
    min(heads(consumer_idx,:),[],1)', ...
    repmat(max_flow_difference,2,1), ...
    'VariableNames',{'Design','HydraulicEntropy_nat', ...
    'ChlorineEntropy_nat', ...
    'MinimumConsumerHead_m','MaxPairFlowDifference_m3h'});
writetable(summary,fullfile(out_dir,'equal_entropy_pair_summary.csv'));

figure_dir=fullfile(root,'manuscript','generated','figures');
if ~isfolder(figure_dir),mkdir(figure_dir);end
plot_pair(diameters,flow,heads,chlorine,local_chlorine_entropy, ...
    chlorine_entropy,node_ids,positive,ends,changed, ...
    fullfile(figure_dir,'tanyimboh_equal_entropy_pair'));
fprintf(['TT pair: max |delta Q| = %.3g m3/h; |delta S_H| = %.3g nat; ' ...
    '|delta S_Cl| = %.3g nat; both-positive changed pipes = %d/8.\n'], ...
    max_flow_difference,entropy_difference,chlorine_entropy_difference, ...
    nnz(changed&both_positive));
clear cleanup
    function dnew=inverse_diameters(hnew)
        old_drop=initial_heads(a)-initial_heads(b);
        new_drop=hnew(a)-hnew(b);
        assert(all(old_drop.*new_drop>0),'Changed heads reversed a pipe');
        dnew=diameters(:,1).*abs(old_drop./new_drop).^(1/4.871);
        assert(all(dnew>=cfg.minimum_diameter & ...
            dnew<=cfg.maximum_diameter),'Inverse diameters outside bounds');
    end
    function gap=chlorine_gap(head4_shift_local)
        h=initial_heads;
        h(node_ids=="3")=h(node_ids=="3")+head3_shift;
        h(node_ids=="4")=h(node_ids=="4")+head4_shift_local;
        dnew=inverse_diameters(h);
        st.setLinkProperty(pipe_ids,'diameter_m',dnew/1000);
        hydraulic_status=st.solveHydraulics();
        assert(hydraulic_status.converged,'Inverse solve failed');
        q=st.solveSteadyQuality('chemical');
        c=1000*double(q.node_concentration_kgm3(qi));
        gap=wdn.staci_chlorine_entropy(st,cfg,c)-target_chlorine_entropy;
    end
end

function plot_pair(d,flow,heads,chlorine,localS,S,node_ids,positive,ends,changed,out)
fig=figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[2 2 39 16]);
t=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
ids=["1","2","3","4","5","6"];
xy=[1.8 2.3;-1.8 2.3;1.8 0;-1.8 0;1.8 -2.3;-1.8 -2.3];
label_xy=[2.17 1.15;-2.17 1.15;-2.17 -1.15;2.17 -1.15; ...
          0.82 1.74;-0.82 0.70;0 -2.82;0 -0.46];
label_align={'left','right','right','left','center','center','center','center'};
pipe_ids=["P1","P4","P7","P6","P2","P3","P8","P5"];
for k=1:2
    ax=nexttile(t);hold(ax,'on');
    for j=1:8
        [~,aa]=ismember(ends(j,1),ids);[~,bb]=ismember(ends(j,2),ids);
        xy1=xy(aa,:);xy2=xy(bb,:);
        plot(ax,[xy1(1),xy2(1)],[xy1(2),xy2(2)],'k-', ...
            'LineWidth',1.1+1.6*d(j,k)/100);
        if flow(j,k)<0, temp=xy1;xy1=xy2;xy2=temp;end
        origin=xy1+0.41*(xy2-xy1);vec=0.14*(xy2-xy1);
        quiver(ax,origin(1),origin(2),vec(1),vec(2),0, ...
            'Color','k','LineWidth',1,'MaxHeadSize',1.5);
    end
    for n=1:numel(ids)
        [~,ni]=ismember(ids(n),node_ids);
        if positive(ni),face=[0.15 0.29 0.46];else,face='w';end
        scatter(ax,xy(n,1),xy(n,2),95,face,'filled', ...
            'MarkerEdgeColor','k','LineWidth',1);
        text(ax,xy(n,1),xy(n,2)+0.25,char(ids(n)), ...
            'FontName','Times New Roman','FontSize',13, ...
            'HorizontalAlignment','center','FontWeight','bold');
        side=sign(xy(n,1));
        node_x=xy(n,1)+side*0.39;
        if side<0,alignment='right';else,alignment='left';end
        node_label=sprintf('H=%.2f m\nc=%.3f mg/L\nS_i=%.4f nat', ...
            heads(ni,k),chlorine(ni,k),localS(ni,k));
        text(ax,node_x,xy(n,2),node_label, ...
            'FontName','Times New Roman','FontSize',10.5, ...
            'HorizontalAlignment',alignment,'VerticalAlignment','middle', ...
            'BackgroundColor','w','Margin',1.2);
    end
    for j=1:8
        % Bold only diameter values that differ between A and B.
        if changed(j)
            diameter_label=sprintf('$\\mathrm{%s}:~d=\\mathbf{%.2f}\\,mm$', ...
                pipe_ids(j),d(j,k));
        else
            diameter_label=sprintf('$\\mathrm{%s}:~d=%.1f\\,mm$', ...
                pipe_ids(j),d(j,k));
        end
        flow_label=sprintf('$|Q|=%.2f\\,\\mathrm{m^3/h}$',abs(flow(j,k)));
        text(ax,label_xy(j,1),label_xy(j,2)+0.14,diameter_label, ...
            'Interpreter','latex','FontName','Times New Roman', ...
            'FontSize',11.5,'HorizontalAlignment',label_align{j}, ...
            'VerticalAlignment','bottom','BackgroundColor','w', ...
            'Margin',0.5);
        text(ax,label_xy(j,1),label_xy(j,2)-0.14,flow_label, ...
            'Interpreter','latex','FontName','Times New Roman', ...
            'FontSize',10.5,'HorizontalAlignment',label_align{j}, ...
            'VerticalAlignment','top','BackgroundColor','w', ...
            'Margin',0.5);
    end
    title(ax,sprintf('(%c) Design %c: $S_{\\mathrm{Cl}}=%.8f$ nat', ...
        'a'+k-1,'A'+k-1,S(k)), ...
        'Interpreter','latex','FontSize',14,'FontWeight','normal');
    xlim(ax,[-5.0,5.0]);ylim(ax,[-3.45,3.0]);axis(ax,'off');
end
exportgraphics(fig,[out '.png'],'Resolution',600);
exportgraphics(fig,[out '.svg'],'ContentType','vector');
close(fig);
end
