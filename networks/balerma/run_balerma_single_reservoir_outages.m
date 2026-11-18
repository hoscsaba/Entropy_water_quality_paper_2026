function summary=run_balerma_single_reservoir_outages( ...
        paper_root,staci_root,mex_dir,requested_reservoirs)
%RUN_BALERMA_SINGLE_RESERVOIR_OUTAGES Replay six saved designs under PDA.
% R38, R43, or R88 is isolated in turn by closing all of its physical
% connectors. The other three fixed-head reservoirs remain connected.
% In each state, 448 nonconnector pipes fail singly; all six direct
% reservoir connectors are protected. Diameters are never reoptimized.
% Previously completed (state,design) blocks are reused only after exact
% diameter-vector and failed-pipe-ID checks. The compatible R43 staging
% checkpoints can be imported after the same checks.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
if nargin<4 || isempty(requested_reservoirs)
    requested_reservoirs=["R38","R43","R88"];
end
requested_reservoirs=string(requested_reservoirs);
requested_reservoirs=requested_reservoirs(:)';
assert(all(ismember(requested_reservoirs,["R38","R43","R88"])));
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config(network_dir);
result_dir=fullfile(network_dir, ...
    'results_staci_uniform_0p1_64in_sourceentry_v4');
out_dir=fullfile(result_dir,'reservoir_outage_comparison');
if ~isfolder(out_dir),mkdir(out_dir);end
cfg.results_dir=char(out_dir);
cfg.stress.allow_pda_tolerance_fallback=true;
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
pda_file=fullfile(out_dir,'runtime','network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,input_file,pda_file);
protected=["5","338","194","223","188","51"];
eligible=string(cfg.design_link_ids(:));
eligible=eligible(~ismember(eligible,protected));
assert(numel(eligible)==448 && numel(unique(eligible))==448);
objectives=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
labels=["Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"];
base=StaciModel(input_file);
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);
base.release();
assert(sum(requested)>0);
rows=cell(numel(requested_reservoirs)*numel(objectives),1);
row_index=0;
for reservoir=requested_reservoirs
    switch reservoir
        case "R38", disabled=string(cfg.stress.r38_connector_link_ids(:));
        case "R43", disabled=string(cfg.stress.r43_connector_link_ids(:));
        case "R88", disabled=string(cfg.stress.r88_connector_link_ids(:));
    end
    state=reservoir+"_unavailable";
    state_dir=fullfile(out_dir,char(state));
    if ~isfolder(state_dir),mkdir(state_dir);end
    state_cfg=cfg;
    state_cfg.stress.disabled_link_ids=cellstr(disabled);
    state_cfg.stress.failed_link_ids=cellstr(eligible);
    previous_diameters=cell(numel(objectives),1);
    previous_cases=cell(numel(objectives),1);
    previous_baseline=nan(numel(objectives),1);
    for j=1:numel(objectives)
        saved=load(fullfile(result_dir,objectives(j)+".mat"),'result');
        assert(strcmp(saved.result.constraint_set_id,cfg.constraint_set_id), ...
            'Saved diameter vector has incompatible constraints');
        x=double(saved.result.design_diameters(:));
        cache_file=fullfile(state_dir,objectives(j)+".mat");
        source="new PDA replay";
        if isfile(cache_file)
            prior=load(cache_file,'cases','baseline_case','diameters');
            assert(isequal(double(prior.diameters(:)),x), ...
                'Outage checkpoint uses another diameter vector');
            cases=prior.cases;baseline_case=prior.baseline_case;
            source="checkpoint";
        else
            duplicate=find(cellfun(@(v)isequal(v,x), ...
                previous_diameters(1:j-1)),1);
            if ~isempty(duplicate)
                cases=previous_cases{duplicate};
                baseline_case=previous_baseline(duplicate);
                source="identical saved design";
            else
                imported=false;
                if reservoir=="R43"
                    old_file=fullfile(network_dir, ...
                        'results_staci_uniform_0p1_64in_staging', ...
                        'pda_replay_cache','R43_unavailable', ...
                        objectives(j)+".mat");
                    if isfile(old_file)
                        old=load(old_file,'cases','design_diameters');
                        if isequal(double(old.design_diameters(:)),x)
                            raw=old.cases;
                            assert(height(raw)==454 && ...
                                numel(unique(string(raw.FailedLinkID)))==454);
                            baseline_rows=raw(ismember( ...
                                string(raw.FailedLinkID),disabled),:);
                            assert(height(baseline_rows)==numel(disabled) && ...
                                max(double(baseline_rows.DeliveredDemandFraction))- ...
                                min(double(baseline_rows.DeliveredDemandFraction)) ...
                                <1e-8, ...
                                'R43 no-op rows disagree');
                            baseline_case=100*double( ...
                                baseline_rows.DeliveredDemandFraction(1));
                            cases=raw(ismember( ...
                                string(raw.FailedLinkID),eligible),:);
                            imported=true;
                            source="validated R43 checkpoint";
                        end
                    end
                end
                if ~imported
                    tic;
                    evalc('[~,cases]=wdn.staci_pda_failure_service(state_cfg,x,labels(j),input_file,pda_file);');
                    baseline_cfg=state_cfg;
                    baseline_cfg.stress.failed_link_ids=cellstr(disabled(1));
                    evalc('[~,no_op]=wdn.staci_pda_failure_service(baseline_cfg,x,labels(j),input_file,pda_file);');
                    assert(height(no_op)==1 && ~no_op.Nonconvergent, ...
                        'Source-only PDA case failed');
                    baseline_case=100*double( ...
                        no_op.DeliveredDemandFraction(1));
                    fprintf('%s / %s: %.1f min\n',state,objectives(j),toc/60);
                end
            end
            diameters=x; %#ok<NASGU>
            save(cache_file,'cases','baseline_case','diameters','-v7');
        end
        assert(height(cases)==448 && ...
            isequal(sort(string(cases.FailedLinkID)),sort(eligible)) && ...
            all(~cases.Nonconvergent), ...
            'Incomplete or nonconvergent %s / %s replay', ...
            state,objectives(j));
        water=100*double(cases.DeliveredDemandFraction);
        chlorine=100*double(cases.QualityCompliantDemandFraction);
        assert(all(isfinite([water;chlorine])) && ...
            all(chlorine<=water+1e-8) && ...
            isfinite(baseline_case));
        previous_diameters{j}=x;
        previous_cases{j}=cases;
        previous_baseline(j)=baseline_case;
        row_index=row_index+1;
        [worst,wi]=min(water);
        worst45=mean(mink(water,45));
        rows{row_index}=table( ...
            objectives(j),labels(j),state,448,baseline_case, ...
            mean(water),worst45,worst, ...
            baseline_case-worst,string(cases.FailedLinkID(wi)), ...
            min(chlorine),nnz(cases.SolverToleranceFallback),source, ...
            'VariableNames',{'Objective','Label','ReservoirState', ...
            'PipeFailureCount','SourceOnlyServicePct', ...
            'MeanWaterPct','Worst45MeanWaterPct','WorstWaterPct', ...
            'AdditionalWorstPipeLossPp','WorstPipeID', ...
            'WorstChlorineCompliantPct','ToleranceFallbackCases', ...
            'DataOrigin'});
        fprintf('%s / %s: source %.2f%%, worst %.2f%% (%s) [%s]\n', ...
            state,objectives(j),baseline_case,worst, ...
            string(cases.FailedLinkID(wi)),source);
    end
    partial=vertcat(rows{1:row_index});
    writetable(partial,fullfile(out_dir, ...
        'single_reservoir_outage_summary.csv'));
end
summary=vertcat(rows{1:row_index});
end
