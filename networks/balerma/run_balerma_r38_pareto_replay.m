function summary=run_balerma_r38_pareto_replay( ...
        paper_root,staci_root,mex_dir,indices,source_state)
%RUN_BALERMA_R38_PARETO_REPLAY Replay selected top-90 Pareto designs.
% Nominal Pareto vectors come from the R38-anchor model. This replay uses
% exactly 448 eligible single-pipe failures. The default source state uses
% all four physical reservoirs. The optional 'r38_unavailable' state
% removes R38 and its P5/P338 connectors; R43/R44/R88 retain their fixed
% heads and protected direct connectors. Each point has a diameter-checked
% checkpoint, so interrupted runs resume without repeats.
if nargin<5 || isempty(source_state),source_state="all_four";end
source_state=string(source_state);
assert(ismember(source_state,["all_four","r38_unavailable"]));
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
result_dir=cfg.results_dir;
if source_state=="r38_unavailable"
    result_dir=fullfile(result_dir,'pareto_r38_unavailable_study');
end
saved=load(fullfile(result_dir,'pareto_cost_branch_hop_top90.mat'),'result');
archive=saved.result;
assert(strcmp(archive.constraint_set_id,cfg.constraint_set_id) && ...
    strcmp(archive.branch_hop_weighting_version, ...
    cfg.branch_hop_weighting.version) && archive.optimized_pipe_count==90, ...
    'Pareto archive has another nominal model');
selected=readtable(fullfile(result_dir,'pareto_selected20_indices.csv'));
if nargin<4 || isempty(indices)
    indices=double(selected.ArchiveIndex(:)');
end
indices=unique(double(indices(:)'));
assert(all(ismember(indices,double(selected.ArchiveIndex))) && ...
    all(indices==floor(indices)),'Only selected archive indices are replayed');
physical=fullfile(network_dir,'input','network_staci_fixed_load.inp');
if source_state=="r38_unavailable"
    replay_dir=fullfile(result_dir,'pareto_failure_replay_r38_unavailable');
    cfg.stress.disabled_link_ids={'5','338'};
    cfg.stress.require_fixed_head_source=true;
else
    replay_dir=fullfile(result_dir,'pareto_failure_replay_protected_all_four');
end
cfg.results_dir=replay_dir;
cfg.runtime_dir=fullfile(replay_dir,'runtime');
checkpoint_dir=fullfile(replay_dir,'checkpoints');
if ~isfolder(checkpoint_dir),mkdir(checkpoint_dir);end
if ~isfolder(cfg.runtime_dir),mkdir(cfg.runtime_dir);end
pda_file=fullfile(cfg.runtime_dir,'network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,physical,pda_file);
if source_state=="r38_unavailable"
    probe=fullfile(cfg.runtime_dir,'r38_boundary_probe.inp');
    connected=wdn.write_staci_connected_outage_input( ...
        pda_file,'5',probe,["5";"338"],true);
    assert(~ismember("38",connected) && ...
        all(ismember(["43";"44";"88"],connected)), ...
        'R38 source boundary was not removed from Pareto replay');
end
base=StaciModel(physical);
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);base.release();
assert(sum(requested)>0,'No Balerma demand');
eligible=string(cfg.stress.failed_link_ids(:));
assert(numel(eligible)==448);
for index=indices
    x=double(archive.designs(index,:));
    checkpoint=fullfile(checkpoint_dir,sprintf('point_%04d.mat',index));
    if isfile(checkpoint)
        prior=load(checkpoint,'diameters','cases');
        assert(isequal(double(prior.diameters(:)'),x(:)') && ...
            height(prior.cases)==448 && all(~prior.cases.Nonconvergent), ...
            'Stale Pareto replay checkpoint %d',index);
        fprintf('Balerma %s Pareto %d: verified checkpoint\n', ...
            source_state,index);
        continue
    end
    started=tic;
    label=sprintf('Pareto %d',index);
    evalc('[~,cases]=wdn.staci_pda_failure_service(cfg,x,label,physical,pda_file);');
    cases.EpanetFallback=false(height(cases),1);
    for j=find(cases.Nonconvergent(:))'
        try
            delivered=[];pressure=[];chlorine=[]; %#ok<NASGU>
            evalc(['[delivered,pressure,chlorine]=' ...
                'wdn.epanet_connected_outage_outputs(' ...
                'cfg,x,pda_file,cases.FailedLinkID(j),cfg.stress.node_ids);']);
            delivered=min(max(delivered(:),0),requested);
            cases.DeliveredDemandFraction(j)=sum(delivered)/sum(requested);
            cases.QualityCompliantDemandFraction(j)= ...
                sum(delivered.*(chlorine(:)>=0.2))/sum(requested);
            cases.PressureViolationFraction(j)= ...
                mean(pressure(:)<cfg.minimum_pressure | ...
                pressure(:)>cfg.maximum_pressure);
            cases.Nonconvergent(j)=false;
            cases.EpanetFallback(j)=true;
            cases.ErrorMessage(j)="STACI nonconverged; EPANET PDA/EPS rescue";
        catch exception
            cases.ErrorMessage(j)="STACI and EPANET failed: "+ ...
                string(exception.message);
        end
    end
    assert(height(cases)==448 && all(~cases.Nonconvergent) && ...
        isequal(sort(string(cases.FailedLinkID)),sort(eligible)), ...
        'Incomplete Pareto PDA replay %d',index);
    diameters=x; %#ok<NASGU>
    save(checkpoint,'diameters','cases','-v7');
    fprintf('Balerma %s Pareto %d: 448 cases in %.1f min, %d EPANET rescues\n', ...
        source_state,index,toc(started)/60,nnz(cases.EpanetFallback));
end
summary=summarize_checkpoints();
    function table_out=summarize_checkpoints()
        rows=cell(numel(selected.ArchiveIndex),1);
        for k=1:numel(rows)
            i=double(selected.ArchiveIndex(k));
            checkpoint=fullfile(checkpoint_dir,sprintf('point_%04d.mat',i));
            if ~isfile(checkpoint)
                rows{k}=[];
                continue
            end
            v=load(checkpoint,'diameters','cases');
            assert(isequal(double(v.diameters(:)'), ...
                double(archive.designs(i,:))) && ...
                height(v.cases)==448 && all(~v.cases.Nonconvergent));
            water=100*double(v.cases.DeliveredDemandFraction);
            chlorine=100*double(v.cases.QualityCompliantDemandFraction);
            [water_worst,wi]=min(water);
            [cl_worst,ci]=min(chlorine);
            rows{k}=table(i,archive.cost(i),archive.branch_hop_entropy(i), ...
                mean(water),water_worst,mean(chlorine),cl_worst, ...
                string(v.cases.FailedLinkID(wi)), ...
                string(v.cases.FailedLinkID(ci)),height(v.cases), ...
                nnz(v.cases.Nonconvergent), ...
                nnz(v.cases.SolverToleranceFallback), ...
                nnz(v.cases.EpanetFallback), ...
                'VariableNames',{'ArchiveIndex','Cost','BranchHopEntropy', ...
                'WaterMeanPct','WaterWorstPct','ClMeanPct','ClWorstPct', ...
                'WaterWorstPipe','ClWorstPipe','FailureCases', ...
                'NonconvergentScenarios','ToleranceFallbackCases', ...
                'EpanetFallbackCases'});
        end
        rows=rows(~cellfun(@isempty,rows));
        if isempty(rows),table_out=table();return;end
        table_out=sortrows(vertcat(rows{:}),'ArchiveIndex');
        writetable(table_out,fullfile(replay_dir, ...
            'pareto_failure_service.csv'));
    end
end
