function out=run_node6_reservoir_pair()
% Exploratory TT pair with a fixed-head reservoir connected at node 6.
% No manuscript or canonical network/result file is changed.
here=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(fileparts(fileparts(here))));
staci_root=fullfile(fileparts(root),'staci');
network_dir=fullfile(root,'networks','tanyimboh_templeman');
addpath(root,network_dir,fullfile(staci_root,'matlab'), ...
    fullfile(staci_root,'build-matlab','Matlab'));
clear network_config
cfg=network_config(network_dir);
cfg.entropy_excluded_link_ids=[cfg.entropy_excluded_link_ids,{'P_R6'}];
cfg.source_node_ids=[cfg.source_node_ids,{'R6'}];
inp=fullfile(here,'network_node6_reservoir.inp');
pipe_ids=string(cfg.design_link_ids(:));
ends=["1","3";"2","4";"4","6";"3","5"; ...
      "1","4";"2","3";"5","6";"3","4"];
archived=load(fullfile(cfg.results_dir,'hydraulic_entropy.mat'),'result');
dA=0.92*double(archived.result.design_diameters(:));
st=StaciModel(inp);release=onCleanup(@()st.release());
st.setLinkProperty(pipe_ids,'diameter_m',dA/1000);
st.resetHydraulicState();
for iter=1:3, status=st.solveHydraulics(); assert(status.converged); end
n=st.nodeResults();node_ids=string(n.id(:));hA=double(n.total_head_m(:));
[found_a,a]=ismember(ends(:,1),node_ids);
[found_b,b]=ismember(ends(:,2),node_ids);
assert(all(found_a&found_b));
old_drop=hA(a)-hA(b);
qA=st.solveSteadyQuality('chemical');
[found_quality,qi]=ismember(node_ids,string(qA.node_ids(:)));
assert(all(found_quality));
cA=1000*double(qA.node_concentration_kgm3(qi));
SClA=wdn.staci_chlorine_entropy(st,cfg,cA);
[SH_A,~]=wdn.staci_flow_entropy(st,cfg,[]);

% Move two internal heads, invert Hazen-Williams losses, and choose the
% second shift so that total stationary chlorine entropy also matches.
found=false;
for shift3=[-0.75,-0.5,0.5,0.75]
    grid=linspace(-1.5,1.5,121);
    gaps=nan(size(grid));
    for j=1:numel(grid)
        gaps(j)=gap_safe(grid(j),shift3);
    end
    crossings=find(isfinite(gaps(1:end-1)) & isfinite(gaps(2:end)) & ...
        gaps(1:end-1).*gaps(2:end)<0);
    for k=crossings
        try
            shift4=fzero(@(z)gap(z,shift3),grid(k:k+1), ...
                optimset('TolX',1e-12,'Display','off'));
            hB=hA;
            hB(node_ids=="3")=hB(node_ids=="3")+shift3;
            hB(node_ids=="4")=hB(node_ids=="4")+shift4;
            dB=inverse_diameters(hB);
            if max(abs(dB-dA))>1
                found=true;break
            end
        catch
        end
    end
    if found,break,end
end
assert(found,'No feasible distinct chlorine-entropy-equal pair found');

D=[dA,dB];
link_flow=cell(1,2);link_ids=cell(1,2);
heads=zeros(numel(node_ids),2);chlorine=zeros(numel(node_ids),2);
SH=zeros(1,2);SCl=zeros(1,2);reservoir_q=zeros(1,2);
for j=1:2
    st.setLinkProperty(pipe_ids,'diameter_m',D(:,j)/1000);
    st.resetHydraulicState();
    for iter=1:3, status=st.solveHydraulics(); assert(status.converged); end
    ns=st.nodeResults();ls=st.linkResults();
    [f,order]=ismember(node_ids,string(ns.id(:)));assert(all(f));
    heads(:,j)=double(ns.total_head_m(order));
    link_ids{j}=string(ls.id(:));
    link_flow{j}=double(ls.flow_rate_m3s(:))*3600;
    reservoir_q(j)=link_flow{j}(link_ids{j}=="P_R6");
    quality=st.solveSteadyQuality('chemical');
    [f,order]=ismember(node_ids,string(quality.node_ids(:)));assert(all(f));
    chlorine(:,j)=1000*double(quality.node_concentration_kgm3(order));
    SH(j)=wdn.staci_flow_entropy(st,cfg,[]);
    SCl(j)=wdn.staci_chlorine_entropy(st,cfg,chlorine(:,j));
end
assert(isequal(link_ids{1},link_ids{2}));
max_flow_difference=max(abs(link_flow{1}-link_flow{2}));
assert(max_flow_difference<1e-5,'Full link flow pattern changed');
assert(abs(diff(SH))<5e-7,'Hydraulic entropy differs');
assert(abs(diff(SCl))<1e-8,'Chlorine entropy differs');
assert(all(D(:)>=cfg.minimum_diameter & D(:)<=cfg.maximum_diameter));
[found_c,ci]=ismember(string(cfg.pressure_node_ids(:)),node_ids);
assert(all(found_c) && all(heads(ci,:)>cfg.minimum_pressure,'all'));
assert(all(chlorine(ci,:)>0.2,'all'));
assert(all(reservoir_q>1),'New reservoir has negligible flow');
assert(all(abs(heads(node_ids=="6",:)-35)<1e-4), ...
    'Node 6 is not held at the prescribed 35 m head');

out=struct('input_file','network_node6_reservoir.inp', ...
    'diameters_mm',D,'link_ids',{link_ids{1}}, ...
    'link_flows_m3h',[link_flow{1},link_flow{2}], ...
    'node_ids',{node_ids},'heads_m',heads,'chlorine_mgL',chlorine, ...
    'hydraulic_entropy_nat',SH,'chlorine_entropy_nat',SCl, ...
    'reservoir_flow_m3h',reservoir_q,'head3_shift_m',shift3, ...
    'head4_shift_m',shift4,'max_flow_difference_m3h',max_flow_difference);
fprintf('Node-6 reservoir pair: SH %.12f/%.12f, SCl %.12f/%.12f, max dQ %.3g m3/h\n', ...
    SH(1),SH(2),SCl(1),SCl(2),max_flow_difference);
fprintf('Head shifts: H3 %.6f m, H4 %.6f m; max |dB-dA| %.3f mm\n', ...
    shift3,shift4,max(abs(dB-dA)));
fprintf('Reservoir flows: %.6f/%.6f m3/h\n',reservoir_q);
disp(table(pipe_ids,dA,dB,dB-dA,'VariableNames', ...
    {'Pipe','DiameterA_mm','DiameterB_mm','Difference_mm'}));
write_design_inp(inp,fullfile(here,'design_A.inp'),pipe_ids,dA);
write_design_inp(inp,fullfile(here,'design_B.inp'),pipe_ids,dB);
link_table=table(pipe_ids,dA,dB,dB-dA, ...
    'VariableNames',{'Pipe','DiameterA_mm','DiameterB_mm','Difference_mm'});
writetable(link_table,fullfile(here,'pair_diameters.csv'));
summary_table=table(["A";"B"],SH(:),SCl(:),reservoir_q(:), ...
    'VariableNames',{'Design','HydraulicEntropy_nat', ...
    'ChlorineEntropy_nat','R6Inflow_m3h'});
writetable(summary_table,fullfile(here,'pair_summary.csv'));
save(fullfile(here,'pair_result.mat'),'out','-v7');

    function dnew=inverse_diameters(hnew)
        new_drop=hnew(a)-hnew(b);
        assert(all(old_drop.*new_drop>0),'Reversed pipe head loss');
        dnew=dA.*abs(old_drop./new_drop).^(1/4.871);
        assert(all(isfinite(dnew) & dnew>=cfg.minimum_diameter & ...
            dnew<=cfg.maximum_diameter),'Diameter outside bounds');
    end
    function v=gap(z,s3)
        h=hA;
        h(node_ids=="3")=h(node_ids=="3")+s3;
        h(node_ids=="4")=h(node_ids=="4")+z;
        dn=inverse_diameters(h);
        st.setLinkProperty(pipe_ids,'diameter_m',dn/1000);
        st.resetHydraulicState();
        for iter=1:3, solved=st.solveHydraulics(); assert(solved.converged); end
        qq=st.solveSteadyQuality('chemical');
        [ff,ii]=ismember(node_ids,string(qq.node_ids(:)));assert(all(ff));
        cc=1000*double(qq.node_concentration_kgm3(ii));
        v=wdn.staci_chlorine_entropy(st,cfg,cc)-SClA;
    end
    function v=gap_safe(z,s3)
        try,v=gap(z,s3);catch,v=NaN;end
    end
end

function write_design_inp(source,target,pipe_ids,diameters_mm)
% Preserve full diameter precision; EPANET's saveInputFile rounds to 4 dp.
lines=splitlines(string(fileread(source)));
in_pipes=false;
fid=fopen(target,'w');assert(fid>0,'Cannot write design INP');
cleanup=onCleanup(@()fclose(fid));
for i=1:numel(lines)
    line=lines(i);
    if i==numel(lines) && strlength(line)==0, break; end
    stripped=strtrim(line);
    if startsWith(stripped,"[")
        in_pipes=strcmpi(stripped,"[PIPES]");
    elseif in_pipes && strlength(stripped)>0 && ~startsWith(stripped,";")
        fields=regexp(char(stripped),'\s+','split');
        [found,index]=ismember(string(fields{1}),pipe_ids);
        if found
            fields{5}=sprintf('%.12f',diameters_mm(index));
            line=strjoin(string(fields),' ');
        end
    end
    fprintf(fid,'%s\n',char(line));
end
clear cleanup
end
