function summary=run_balerma_common_pareto_replay( ...
        paper_root,staci_root,mex_dir,result_dir,requested_indices,disabled_reservoir)
%RUN_BALERMA_COMMON_PARETO_REPLAY PDA replay of saved top-90 Pareto designs.
% Each design is tested after every physical-pipe failure with all four
% reservoirs and with one selected reservoir unavailable. The default is
% R44; R38 and R43 use separate replay directories. Any source state can
% reuse saved all-four-reservoir cases when archived vectors match. STACI
% solves steady chlorine; unresolved PDA
% cases are independently rescued by EPANET 2.2.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
if nargin<4 || isempty(result_dir)
    result_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_sourceentry_v4');
end
if nargin<6 || isempty(disabled_reservoir),disabled_reservoir="R44";end
disabled_reservoir=string(disabled_reservoir);
assert(ismember(disabled_reservoir,["R43","R38","R44"]), ...
    'Only R43, R38 or R44 can be disabled in this Balerma replay');
switch disabled_reservoir
    case "R38"
        unavailable_state="R38_unavailable";
        disabled_links=cfg_r38_connectors(network_dir);
        replay_name='pareto_failure_replay_r38';
    case "R44"
        unavailable_state="R44_unavailable";
        disabled_links=cfg_r44_connectors(network_dir);
        replay_name='pareto_failure_replay_r44';
    otherwise
        unavailable_state="R43_unavailable";
        disabled_links=cfg_r43_connectors(network_dir);
        replay_name='pareto_failure_replay';
end
cfg=network_config(network_dir);
archive_file=fullfile(result_dir,'pareto_cost_branch_hop_top90.mat');
saved=load(archive_file,'result');archive=saved.result;
if disabled_reservoir=="R44"
    assert(isfield(archive,'branch_hop_weighting_version') && ...
        strcmp(archive.branch_hop_weighting_version, ...
            cfg_r44_weight_version(network_dir)), ...
        'R44 Pareto replay requires the corrected zero-hop reservoir weights');
end
assert(strcmp(archive.constraint_set_id,cfg.constraint_set_id) && ...
    archive.optimized_pipe_count==90 && ...
    all(archive.max_constraint_violation<=cfg.ga.constraint_tolerance), ...
    'Balerma Pareto archive has the wrong nominal feasible set');
designs=double(archive.designs);
assert(size(designs,2)==454,'Each Pareto vector must contain 454 pipes');
n=size(designs,1);
if nargin<5 || isempty(requested_indices),requested_indices=1:n;end
requested_indices=unique(double(requested_indices(:)'));
assert(all(requested_indices>=1 & requested_indices<=n & ...
    requested_indices==floor(requested_indices)), ...
    'Invalid Balerma Pareto archive indices');
replay_dir=fullfile(result_dir,replay_name);
% Keep EPANET fallback scratch files private to this replay worker.
cfg.results_dir=fullfile(replay_dir, ...
    sprintf('worker_%04d',requested_indices(1)));
if ~isfolder(fullfile(cfg.results_dir,'runtime'))
    mkdir(fullfile(cfg.results_dir,'runtime'));
end
checkpoint_dir=fullfile(replay_dir,'checkpoints');
if ~isfolder(checkpoint_dir),mkdir(checkpoint_dir);end
if ~isfolder(fullfile(replay_dir,'runtime'))
    mkdir(fullfile(replay_dir,'runtime'));
end
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
pda_file=fullfile(replay_dir,'runtime', ...
    sprintf('network_pda_fixed_load_%04d.inp',requested_indices(1)));
wdn.write_staci_pda_input(cfg,input_file,pda_file);
base=StaciModel(input_file);
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);base.release();
assert(sum(requested)>0,'Balerma has no requested consumer demand');
states=["all_four",unavailable_state];
for index=requested_indices
    checkpoint=fullfile(checkpoint_dir,sprintf('point_%04d.mat',index));
    x=designs(index,:);
    if isfile(checkpoint)
        prior=load(checkpoint,'diameters','row');
        assert(isequal(double(prior.diameters(:)'),x) && ...
            prior.row.NonconvergentScenarios==0, ...
            'Stale or incomplete Pareto replay checkpoint %d',index);
        fprintf('Balerma Pareto %d/%d: verified checkpoint\n',index,n);
        continue
    end
    started=tic;
    all_cases=table();
    for state=states
        state_cfg=cfg;
        if state==unavailable_state
            state_cfg.stress.disabled_link_ids=disabled_links;
        end
        original_checkpoint=fullfile(result_dir, ...
            'pareto_failure_replay','checkpoints', ...
            sprintf('point_%04d.mat',index));
        can_reuse=false;
        if state=="all_four" && isfile(original_checkpoint)
            original=load(original_checkpoint,'diameters','all_cases');
            can_reuse=isequal(double(original.diameters(:)'),x);
        end
        if can_reuse
            cases=original.all_cases( ...
                original.all_cases.ReservoirAvailability=="all_four",:);
            assert(height(cases)==454 && all(~cases.Nonconvergent), ...
                'Incomplete all-four-reservoir cache for Pareto point %d',index);
        else
            label=sprintf('Pareto %d / %s',index,state);
            evalc('[~,cases]=wdn.staci_pda_failure_service(state_cfg,x,label,input_file,pda_file);');
        end
        cases.EpanetFallback=false(height(cases),1);
        for bad=find(cases.Nonconvergent(:))'
            try
                evalc('[delivered,pressure,chlorine]=wdn.epanet_connected_outage_outputs(state_cfg,x,pda_file,cases.FailedLinkID(bad),cfg.stress.node_ids);');
                delivered=min(max(delivered(:),0),requested);
                cases.DeliveredDemandFraction(bad)= ...
                    sum(delivered)/sum(requested);
                cases.QualityCompliantDemandFraction(bad)= ...
                    sum(delivered.*(chlorine(:)>=0.2))/sum(requested);
                cases.PressureViolationFraction(bad)= ...
                    mean(pressure(:)<cfg.minimum_pressure | ...
                    pressure(:)>cfg.maximum_pressure);
                cases.Nonconvergent(bad)=false;
                cases.EpanetFallback(bad)=true;
                cases.ErrorMessage(bad)= ...
                    "STACI nonconverged; EPANET 2.2 PDA/EPS rescue";
            catch exception
                cases.ErrorMessage(bad)= ...
                    "STACI and EPANET failed: "+string(exception.message);
            end
        end
        if height(cases)~=454 || any(cases.Nonconvergent)
            debug_file=fullfile(replay_dir, ...
                sprintf('unresolved_%04d_%s.mat',index,char(state)));
            save(debug_file,'cases','x','state_cfg','-v7');
            fprintf('Saved unresolved cases in %s\n',debug_file);
        end
        assert(height(cases)==454 && all(~cases.Nonconvergent), ...
            'Incomplete Balerma Pareto replay %d/%s',index,state);
        cases.ReservoirAvailability=repmat(state,height(cases),1);
        if isempty(all_cases),all_cases=cases;
        else,all_cases=[all_cases;cases];end %#ok<AGROW>
    end
    assert(height(all_cases)==908,'Expected 908 Balerma outage cases');
    water=100*double(all_cases.DeliveredDemandFraction);
    cl=100*double(all_cases.QualityCompliantDemandFraction);
    [water_worst,wi]=min(water);
    [cl_worst,ci]=min(cl);
    row=table(index,archive.cost(index), ...
        archive.branch_hop_entropy(index),mean(water),water_worst, ...
        mean(cl),cl_worst, ...
        string(all_cases.FailedLinkID(wi)), ...
        string(all_cases.ReservoirAvailability(wi)), ...
        string(all_cases.FailedLinkID(ci)), ...
        string(all_cases.ReservoirAvailability(ci)), ...
        height(all_cases),nnz(all_cases.Nonconvergent), ...
        nnz(all_cases.SolverToleranceFallback),toc(started), ...
        nnz(all_cases.EpanetFallback), ...
        'VariableNames',{'ArchiveIndex','Cost','BranchHopEntropy', ...
        'WaterMeanPct','WaterWorstPct','ClMeanPct','ClWorstPct', ...
        'WaterWorstPipe','WaterWorstAvailability','ClWorstPipe', ...
        'ClWorstAvailability','FailureCases','NonconvergentScenarios', ...
        'ToleranceFallbackCases','ReplaySeconds','EpanetFallbackCases'});
    diameters=x; %#ok<NASGU>
    save(checkpoint,'diameters','row','all_cases','-v7');
    fprintf('Balerma Pareto %d/%d: 908 cases, water %.2f%%, Cl %.2f%%\n', ...
        index,n,water_worst,cl_worst);
end
files=dir(fullfile(checkpoint_dir,'point_*.mat'));
summary=table();
for k=1:numel(files)
    item=load(fullfile(checkpoint_dir,files(k).name),'diameters','row');
    ix=item.row.ArchiveIndex;
    assert(isequal(double(item.diameters(:)'),designs(ix,:)), ...
        'Pareto replay checkpoint design mismatch');
    summary=[summary;item.row]; %#ok<AGROW>
end
summary=sortrows(summary,'ArchiveIndex');
if numel(requested_indices)==n
    assert(height(summary)==n,'Missing Pareto replay checkpoints');
    writetable(summary,fullfile(replay_dir,'pareto_failure_service.csv'));
end
end

function ids=cfg_r38_connectors(network_dir)
ids={'5','338'};
assert_reservoir_connectors(network_dir,ids,'38');
end

function ids=cfg_r43_connectors(network_dir)
ids={'194','223'};
assert_reservoir_connectors(network_dir,ids,'43');
end

function ids=cfg_r44_connectors(network_dir)
ids={'188'};
assert_reservoir_connectors(network_dir,ids,'44');
end

function version=cfg_r44_weight_version(network_dir)
cfg=network_config(network_dir);
weighting=balerma_connected_branch_weights(cfg);
version=weighting.version;
end

function assert_reservoir_connectors(network_dir,ids,reservoir_id)
text=fileread(fullfile(network_dir,'input','network_original.inp'));
for k=1:numel(ids)
    pattern=['(?m)^\s*' ids{k} '\s+(?:' reservoir_id '\s+\S+|\S+\s+' reservoir_id ')\s+'];
    assert(~isempty(regexp(text,pattern,'once')), ...
        'Balerma reservoir connector %s no longer matches the INP',ids{k});
end
end
