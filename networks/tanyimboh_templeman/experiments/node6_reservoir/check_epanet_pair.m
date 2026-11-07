function check_epanet_pair()
% Independent EPANET hydraulic replay of the isolated node-6 reservoir pair.
here=fileparts(mfilename('fullpath'));
root=fileparts(fileparts(fileparts(fileparts(here))));
addpath(fullfile(root,'third_party','epanet_matlab_toolkit_patch'));
library=fullfile(root,'third_party','epanet22_arm64','libepanet2.dylib');
out=load(fullfile(here,'pair_result.mat'),'out');
out=out.out;
flow=nan(numel(out.link_ids),2);
head=zeros(numel(out.node_ids),2);
for k=1:2
    case_names=["design_A.inp","design_B.inp"];
    ep=epanet(char(fullfile(here,case_names(k))),library);
    cleanup=onCleanup(@()ep.unload());
    ids=string(ep.getLinkNameID);ids=ids(:);
    ep.solveCompleteHydraulics();
    [found,li]=ismember(string(out.link_ids),ids);
    assert(all(ismember(string(out.link_ids(~found)), ...
        ["EPANET_RESERVOIR_R6","EPANET_RESERVOIR_8"])), ...
        'Unexpected link ID mismatch');
    f=double(ep.getLinkFlows);f=f(:);
    flow(found,k)=f(li(found));
    ni=string(ep.getNodeNameID);ni=ni(:);
    [found,order]=ismember(string(out.node_ids),ni);
    assert(all(found),'Node ID mismatch');
    h=double(ep.getNodeHydraulicHead);h=h(:);
    head(:,k)=h(order);
    clear cleanup
end
fprintf('EPANET max A-B flow difference %.9g m3/h\n',max(abs(diff(flow,1,2)),[],'all','omitnan'));
fprintf('EPANET max A-B STACI flow difference %.9g m3/h\n',max(abs(flow-out.link_flows_m3h),[],'all','omitnan'));
fprintf('EPANET reservoir flows %.9g / %.9g m3/h\n',flow(out.link_ids=="P_R6",:));
fprintf('EPANET node 6 heads %.9g / %.9g m\n',head(out.node_ids=="6",:));
save(fullfile(here,'epanet_result.mat'),'flow','head','-v7');
end
