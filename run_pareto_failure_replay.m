function summary = run_pareto_failure_replay( ...
        paper_root, staci_root, mex_dir, network_name, requested_indices, ...
        result_dir_override)
%RUN_PARETO_FAILURE_REPLAY Replay every saved cost/branch-hop Pareto design.
% This does not optimize diameters. The TT study closes each of eight pipes
% with its two original supplies available. Anytown closes each of 38 pipes
% with both physical 215-ft auxiliary reservoirs, R65 only, and R165 only.
% All failed states use PDA. STACI solves hydraulics and stationary chlorine
% in memory; a few TT states that remain nonconvergent after a documented
% tolerance retry use EPANET 2.2 PDA and extended-period chlorine instead.
% Each archive point is checkpointed; a later call skips verified points.
if nargin<5, requested_indices=[]; end
if nargin<6, result_dir_override=[]; end
addpath(paper_root,fullfile(staci_root,'matlab'),mex_dir);
network_name=string(network_name);
network_dir=fullfile(paper_root,'networks',char(network_name));
addpath(network_dir,'-begin');
clear network_config
if network_name=="tanyimboh_templeman"
    cfg=network_config(network_dir);
    if ~isempty(result_dir_override)
        cfg.results_dir=char(result_dir_override);
    end
    archive_file=fullfile(cfg.results_dir,'pareto_cost_branch_hop.mat');
    saved=load(archive_file,'result'); archive=saved.result;
    original_file=cfg.inp_file;
    availability_names="both_sources";
elseif network_name=="anytown"
    cfg=network_config_anchor_replay(network_dir);
    archive_file=fullfile(cfg.results_dir,'pareto_plot_archive.mat');
    saved=load(archive_file,'plot_result'); archive=saved.plot_result;
    source_cfg=network_config_physical_reservoirs(network_dir);
    original_file=source_cfg.inp_file;
    availability_names=["both","only_R65","only_R165"];
else
    error('The Pareto replay supports only TT and Anytown');
end
assert(strcmp(archive.constraint_set_id, ...
    'pressure_10_120m_chlorine_mass_split_v2'), ...
    'Pareto archive uses a different nominal feasible set');
assert(all(archive.max_constraint_violation<=cfg.ga.constraint_tolerance), ...
    'Pareto archive contains an infeasible nominal design');
designs=double(archive.designs);
assert(size(designs,2)==numel(cfg.design_link_ids), ...
    'Pareto design columns do not match physical pipes');
n=size(designs,1);
if isempty(requested_indices),requested_indices=1:n;end
requested_indices=unique(double(requested_indices(:)'));
assert(all(requested_indices>=1 & requested_indices<=n & ...
    requested_indices==floor(requested_indices)), 'Invalid archive indices');

replay_dir=fullfile(cfg.results_dir,'pareto_failure_replay');
checkpoint_dir=fullfile(replay_dir,'checkpoints');
scenario_dir=fullfile(replay_dir,'scenarios');
if ~isfolder(checkpoint_dir),mkdir(checkpoint_dir);end
if ~isfolder(scenario_dir),mkdir(scenario_dir);end
cfg.results_dir=replay_dir; % Only scratch outage INPs go under this folder.
cfg.stress.allow_pda_tolerance_fallback=true;
base_files=strings(numel(availability_names),1);
pda_files=strings(numel(availability_names),1);
if network_name=="tanyimboh_templeman"
    base_files(1)=original_file;
    pda_files(1)=fullfile(scenario_dir,'tt_pda.inp');
    wdn.write_staci_pda_input(cfg,original_file,pda_files(1));
else
    available={ ["65";"165"],"65","165" };
    for a=1:numel(availability_names)
        base_files(a)=fullfile(scenario_dir, ...
            availability_names(a)+'_fixed_load.inp');
        pda_files(a)=fullfile(scenario_dir, ...
            availability_names(a)+'_pda.inp');
        wdn.write_anytown_physical_availability_input(source_cfg, ...
            original_file,base_files(a),available{a},'dda');
        wdn.write_anytown_physical_availability_input(source_cfg, ...
            original_file,pda_files(a),available{a},'pda');
    end
end
for index=requested_indices
    checkpoint=fullfile(checkpoint_dir,sprintf('point_%04d.mat',index));
    x=designs(index,:);
    if isfile(checkpoint)
        prior=load(checkpoint,'diameters','row');
        assert(max(abs(double(prior.diameters(:)')-x))<1e-9, ...
            'Archive point %d changed; remove its stale checkpoint',index);
        assert(prior.row.NonconvergentScenarios==0, ...
            'Checkpoint %d contains a failed hydraulic solve',index);
        fprintf('%s Pareto %d/%d: verified checkpoint\n',network_name,index,n);
        continue
    end
    started=tic;
    all_cases=table();
    for a=1:numel(availability_names)
        label=sprintf('Pareto %d / %s',index,availability_names(a));
        % STACI prints one import notice per failed pipe. Capture those
        % routine notices so the replay log reports one line per design.
        evalc('[~,cases]=wdn.staci_pda_failure_service(cfg,x,label,base_files(a),pda_files(a));');
        cases.EpanetFallback=false(height(cases),1);
        if any(cases.Nonconvergent)
            base=StaciModel(base_files(a));
            requested=max(double(base.getNodeProperty( ...
                string(cfg.stress.node_ids(:)),'demand_m3s')),0);
            base.release();
            requested=requested(:);
            for failed_index=find(cases.Nonconvergent(:))'
                [delivered,pressure,concentration]= ...
                    wdn.epanet_connected_outage_outputs(cfg,x,pda_files(a), ...
                    cases.FailedLinkID(failed_index),cfg.stress.node_ids);
                delivered=min(max(delivered(:),0),requested);
                cases.DeliveredDemandFraction(failed_index)= ...
                    sum(delivered)/sum(requested);
                cases.QualityCompliantDemandFraction(failed_index)= ...
                    sum(delivered.*(concentration(:)>= ...
                    cfg.stress.minimum_chlorine))/sum(requested);
                cases.PressureViolationFraction(failed_index)= ...
                    mean(pressure(:)<cfg.minimum_pressure | ...
                    pressure(:)>cfg.maximum_pressure);
                cases.Nonconvergent(failed_index)=false;
                cases.EpanetFallback(failed_index)=true;
                cases.ErrorMessage(failed_index)= ...
                    "STACI nonconverged; EPANET 2.2 PDA/EPS rescue";
            end
        end
        cases.Availability=repmat(availability_names(a),height(cases),1);
        if isempty(all_cases),all_cases=cases;else,all_cases=[all_cases;cases];end %#ok<AGROW>
    end
    failed=nnz(all_cases.Nonconvergent);
    assert(failed==0, ...
        'Pareto point %d has %d nonconvergent outage states',index,failed);
    expected=numel(cfg.stress.failed_link_ids)*numel(availability_names);
    assert(height(all_cases)==expected,'Wrong number of outage cases');
    water=100*all_cases.DeliveredDemandFraction;
    chlorine=100*all_cases.QualityCompliantDemandFraction;
    [water_worst,wi]=min(water);
    [chlorine_worst,ci]=min(chlorine);
    row=table(index,archive.cost(index),archive.branch_hop_entropy(index), ...
        mean(water),water_worst,mean(chlorine),chlorine_worst, ...
        string(all_cases.FailedLinkID(wi)), ...
        string(all_cases.Availability(wi)), ...
        string(all_cases.FailedLinkID(ci)), ...
        string(all_cases.Availability(ci)),expected,failed, ...
        nnz(all_cases.SolverToleranceFallback),toc(started), ...
        nnz(all_cases.EpanetFallback), ...
        'VariableNames',{'ArchiveIndex','Cost','BranchHopEntropy', ...
        'WaterMeanPct','WaterWorstPct','ClMeanPct','ClWorstPct', ...
        'WaterWorstPipe','WaterWorstAvailability','ClWorstPipe', ...
        'ClWorstAvailability','FailureCases','NonconvergentScenarios', ...
        'ToleranceFallbackCases', ...
        'ReplaySeconds','EpanetFallbackCases'});
    diameters=x; %#ok<NASGU>
    save(checkpoint,'diameters','row','all_cases','-v7');
    fprintf('%s Pareto %d/%d: %d cases, water %.2f%%, Cl %.2f%%, %.1f s\n', ...
        network_name,index,n,expected,water_worst,chlorine_worst,row.ReplaySeconds);
end
checkpoint_files=dir(fullfile(checkpoint_dir,'point_*.mat'));
summary=table();
for k=1:numel(checkpoint_files)
    item=load(fullfile(checkpoint_dir,checkpoint_files(k).name), ...
        'diameters','row');
    if ~ismember('EpanetFallbackCases',item.row.Properties.VariableNames)
        item.row.EpanetFallbackCases=0;
    end
    ix=item.row.ArchiveIndex;
    assert(max(abs(double(item.diameters(:)')-designs(ix,:)))<1e-9, ...
        'A checkpoint does not match this Pareto archive');
    summary=[summary;item.row]; %#ok<AGROW>
end
summary=sortrows(summary,'ArchiveIndex');
writetable(summary,fullfile(replay_dir,'pareto_failure_service.csv'));
save(fullfile(replay_dir,'pareto_failure_service.mat'), ...
    'summary','archive_file','availability_names','-v7');
fprintf('%s: %d/%d Pareto designs have complete PDA replay\n', ...
    network_name,height(summary),n);
end
