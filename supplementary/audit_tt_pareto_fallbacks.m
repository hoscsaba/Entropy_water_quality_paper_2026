function audit = audit_tt_pareto_fallbacks(paper_root, staci_root, mex_dir, results_dir)
%AUDIT_TT_PARETO_FALLBACKS Independently check difficult PDA outage states.
% The Pareto replay first uses STACI. If the default Newton solve fails,
% it retries with a documented continuity tolerance. A few states require
% EPANET 2.2 instead. This audit reruns every such state in EPANET and
% compares the demand-weighted service fractions on the same outage graph.
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_dir=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(network_dir,'-begin'); clear network_config
cfg=network_config(network_dir);
if nargin>=4 && ~isempty(results_dir)
    cfg.results_dir=char(results_dir);
end
root=fullfile(cfg.results_dir,'pareto_failure_replay');
cfg.results_dir=root;
inp=fullfile(root,'scenarios','tt_pda.inp');
base=StaciModel(fullfile(network_dir,'input','network_staci_fixed_load.inp'));
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
base.release(); requested=requested(:);
files=dir(fullfile(root,'checkpoints','point_*.mat'));
archive_index=[]; pipe_id=strings(0,1); staci_water=[]; epanet_water=[];
staci_chlorine=[]; epanet_chlorine=[]; was_epanet=[];
for j=1:numel(files)
    point=load(fullfile(files(j).folder,files(j).name), ...
        'diameters','all_cases','row');
    cases=point.all_cases;
    if ~ismember('EpanetFallback',cases.Properties.VariableNames)
        cases.EpanetFallback=false(height(cases),1);
    end
    selected=find(cases.SolverToleranceFallback | cases.EpanetFallback);
    for k=selected(:)'
        [delivered,~,chlorine]=wdn.epanet_connected_outage_outputs( ...
            cfg,point.diameters,inp,cases.FailedLinkID(k),cfg.stress.node_ids);
        delivered=min(max(delivered(:),0),requested);
        archive_index(end+1,1)=point.row.ArchiveIndex; %#ok<AGROW>
        pipe_id(end+1,1)=string(cases.FailedLinkID(k)); %#ok<AGROW>
        staci_water(end+1,1)=100*cases.DeliveredDemandFraction(k); %#ok<AGROW>
        epanet_water(end+1,1)=100*sum(delivered)/sum(requested); %#ok<AGROW>
        staci_chlorine(end+1,1)= ...
            100*cases.QualityCompliantDemandFraction(k); %#ok<AGROW>
        epanet_chlorine(end+1,1)=100*sum(delivered.* ...
            (chlorine(:)>=cfg.stress.minimum_chlorine))/sum(requested); %#ok<AGROW>
        was_epanet(end+1,1)=logical(cases.EpanetFallback(k)); %#ok<AGROW>
    end
end
audit=table(archive_index,pipe_id,staci_water,epanet_water, ...
    staci_chlorine,epanet_chlorine,was_epanet, ...
    'VariableNames',{'ArchiveIndex','FailedPipe','SavedWaterPct', ...
    'EpanetWaterPct','SavedClPct','EpanetClPct','WasEpanetRescue'});
audit.WaterDifferencePP=abs(audit.SavedWaterPct-audit.EpanetWaterPct);
audit.ClDifferencePP=abs(audit.SavedClPct-audit.EpanetClPct);
writetable(audit,fullfile(root,'tt_fallback_epanet_audit.csv'));
fprintf('TT fallback audit: %d cases, max water %.4g pp, max Cl %.4g pp\n', ...
    height(audit),max(audit.WaterDifferencePP),max(audit.ClDifferencePP));
end
