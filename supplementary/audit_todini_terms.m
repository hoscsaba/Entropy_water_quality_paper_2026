%AUDIT_TODINI_TERMS Independent energy-term check of three saved designs.
% Run this script from MATLAB after building the STACI MEX extension.
% Optional: set WDS_STACI_ROOT when STACI is not next to this repository.
paper_root=fileparts(fileparts(mfilename('fullpath')));
staci_root=getenv('WDS_STACI_ROOT');
if isempty(staci_root)
    staci_root=fullfile(fileparts(paper_root),'staci');
end
addpath(paper_root,fullfile(staci_root,'matlab'), ...
    fullfile(staci_root,'build-matlab','Matlab'));
cases={ ...
    'tanyimboh_templeman','results_staci_10_120_clsplit_v2'; ...
    'anytown','results_staci_anchor_replay'; ...
    'balerma','results_staci_uniform_0p1_64in_staging'};
for j=1:size(cases,1)
    network_dir=fullfile(paper_root,'networks',cases{j,1});
    addpath(network_dir);
    if strcmp(cases{j,1},'anytown')
        cfg=network_config_anchor_replay(network_dir);
    else
        cfg=network_config(network_dir);
    end
    saved=load(fullfile(network_dir,cases{j,2},'todini.mat'),'result');
    result=saved.result;
    cfg.inp_file=char(result.input_file);
    if ~startsWith(cfg.inp_file,filesep)
        cfg.inp_file=fullfile(paper_root,cfg.inp_file);
    end
    model=StaciModel(cfg.inp_file);
    cleaner=onCleanup(@()model.release());
    if strcmp(cases{j,1},'anytown')
        diameter_scale=0.0254;
    else
        diameter_scale=0.001;
    end
    model.setLinkProperty(string(cfg.design_link_ids(:)), ...
        'diameter_m',double(result.design_diameters(:))*diameter_scale);
    status=model.solveHydraulics();assert(status.converged);
    nodes=model.nodeResults();links=model.linkResults();
    demand=double(nodes.demand_m3s(:));
    head=double(nodes.total_head_m(:));
    required=double(nodes.elevation_m(:))+cfg.minimum_pressure;
    q=max(demand,0);
    numerator=sum(q.*(head-required));
    required_energy=sum(q.*required);
    inlet_energy=sum(max(-demand,0).*head);
    boundary=string(links.type(:))=="KonstNyomas" & ...
        string(links.to_node(:))=="";
    boundary_flow=double(links.flow_rate_m3s(boundary));
    boundary_ids=string(links.from_node(boundary));
    [found,bi]=ismember(boundary_ids,string(nodes.id(:)));assert(all(found));
    reservoir_energy=sum(max(-boundary_flow,0).*head(bi));
    pump=ismember(string(links.type(:)),["Szivattyu","EpanetPowerPump"]);
    pump_flow=double(links.flow_rate_m3s(pump));
    pump_gain=-double(links.headloss_m(pump));
    pump_energy=sum(max(pump_flow,0).*max(pump_gain,0));
    denominator=inlet_energy+reservoir_energy+pump_energy-required_energy;
    hand=numerator/denominator;
    code=wdn.staci_todini_index(model,cfg);
    fprintf('%s: numerator %.12g; fixed-flow inlet %.12g; reservoir %.12g; pump %.12g; required %.12g; denominator %.12g; hand %.12g; code %.12g; saved %.12g; boundary flows %s; pump types %s\n', ...
        cases{j,1},numerator,inlet_energy,reservoir_energy, ...
        pump_energy,required_energy,denominator,hand,code, ...
        result.metrics.todini,mat2str(boundary_flow(:)',6), ...
        strjoin(string(links.type(pump)),','));
    assert(abs(hand-code)<1e-10);
    assert(abs(hand-result.metrics.todini)<1e-5);
    clear cleaner model
    rmpath(network_dir);
end
