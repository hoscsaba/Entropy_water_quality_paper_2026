function [summary,scenarios,vulnerability] = run_balerma_uniform_pda_replay( ...
        paper_root,staci_root,mex_dir,result_dir,disabled_reservoir)
%RUN_BALERMA_UNIFORM_PDA_REPLAY Two reservoir states x 454 pipe failures.
% Uses saved 0.1--64-in diameter vectors; does no optimization or DDA solve.
% The second state isolates one physical reservoir at all its connectors.
% Each (design, availability) block is cached, so interruptions can resume.
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config(network_dir);
if nargin<4 || isempty(result_dir)
    result_dir=fullfile(network_dir,'results_staci_uniform_0p1_64in_sourceentry_v4');
end
cfg.results_dir=char(result_dir);
cfg.stress.allow_pda_tolerance_fallback=true;
input_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
if nargin<5 || isempty(disabled_reservoir),disabled_reservoir="R44";end
disabled_reservoir=string(disabled_reservoir);
switch disabled_reservoir
    case "R43", disabled_links=cfg.stress.r43_connector_link_ids;
    case "R38", disabled_links=cfg.stress.r38_connector_link_ids;
    case "R44", disabled_links=cfg.stress.r44_connector_link_ids;
    otherwise, error('Unsupported Balerma reservoir outage: %s',disabled_reservoir);
end
source_text=fileread(input_file);
reservoir_id=char(extractAfter(disabled_reservoir,1));
for connector=string(disabled_links(:))'
    pattern=['(?m)^\s*' char(connector) '\s+(?:' reservoir_id ...
        '\s+\S+|\S+\s+' reservoir_id ')\s+'];
    assert(~isempty(regexp(source_text,pattern,'once')), ...
        'Reservoir connector %s no longer matches the Balerma INP',connector);
end
unavailable_state=disabled_reservoir+"_unavailable";
pda_file=fullfile(result_dir,'runtime','network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,input_file,pda_file);
base=StaciModel(input_file);
requested=max(double(base.getNodeProperty( ...
    string(cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);
base.release();
assert(sum(requested)>0,'Balerma has no requested consumer demand');
objectives=["cost","hydraulic_entropy", ...
    "branch_hop_weighted_entropy","chlorine_concentration", ...
    "chlorine_entropy","todini"];
labels=["Cost","Flow entropy","Branch-hop entropy", ...
    "Cl concentration","Cl entropy","Todini"];
states=["all_four",unavailable_state];
all_rows=cell(numel(objectives),1);
all_scenarios=cell(numel(objectives),1);
all_vulnerability=cell(numel(objectives),1);
for j=1:numel(objectives)
    saved=load(fullfile(result_dir,objectives(j)+'.mat'),'result');
    assert(strcmp(saved.result.constraint_set_id,cfg.constraint_set_id), ...
        'Balerma replay design has incompatible constraints');
    if objectives(j)=="branch_hop_weighted_entropy"
        weighting=balerma_connected_branch_weights(cfg);
        assert(isfield(saved.result,'branch_hop_weighting') && ...
            isfield(saved.result.branch_hop_weighting,'version') && ...
            strcmp(saved.result.branch_hop_weighting.version, ...
            weighting.version), ...
            'Balerma replay branch-hop design uses obsolete source weights');
    end
    x=double(saved.result.design_diameters(:));
    cases_by_state=cell(numel(states),1);
    for s=1:numel(states)
        state=states(s);
        state_cfg=cfg;
        if state==unavailable_state
            state_cfg.stress.disabled_link_ids=disabled_links;
        end
        cache_dir=fullfile(result_dir,'pda_replay_cache',char(state));
        if ~isfolder(cache_dir),mkdir(cache_dir);end
        cache_file=fullfile(cache_dir,objectives(j)+'.mat');
        if isfile(cache_file)
            prior=load(cache_file,'cases','design_diameters');
            assert(isequal(prior.design_diameters,x), ...
                'Cached replay belongs to another diameter vector');
            cases=prior.cases;
        else
            % Component isolation can import many temporary INPs; keep
            % per-case solver messages out of the reproducibility log.
            evalc('[~,cases]=wdn.staci_pda_failure_service(state_cfg,x,labels(j),input_file,pda_file);');
            cases.EpanetFallback=false(height(cases),1);
            for k=find(cases.Nonconvergent(:))'
                try
                    [delivered,pressure,chlorine]= ...
                        wdn.epanet_connected_outage_outputs( ...
                        state_cfg,x,pda_file,cases.FailedLinkID(k), ...
                        cfg.stress.node_ids);
                    delivered=min(max(delivered(:),0),requested);
                    cases.DeliveredDemandFraction(k)= ...
                        sum(delivered)/sum(requested);
                    cases.QualityCompliantDemandFraction(k)= ...
                        sum(delivered.*(chlorine(:)>=0.2))/sum(requested);
                    cases.PressureViolationFraction(k)= ...
                        mean(pressure(:)<cfg.minimum_pressure | ...
                        pressure(:)>cfg.maximum_pressure);
                    cases.Nonconvergent(k)=false;
                    cases.EpanetFallback(k)=true;
                    cases.ErrorMessage(k)= ...
                        "STACI nonconverged; EPANET 2.2 PDA/EPS rescue";
                catch exception
                    cases.ErrorMessage(k)= ...
                        "STACI and EPANET failed: "+string(exception.message);
                end
            end
            design_diameters=x; %#ok<NASGU>
            save(cache_file,'cases','design_diameters','-v7');
        end
        assert(height(cases)==numel(cfg.stress.failed_link_ids) && ...
            all(~cases.Nonconvergent), ...
            'Incomplete Balerma PDA replay: %s/%s',objectives(j),state);
        cases.Objective=repmat(objectives(j),height(cases),1);
        cases.ReservoirAvailability=repmat(state,height(cases),1);
        cases_by_state{s}=cases;
        fprintf('Balerma PDA %s/%s: %d cases complete\n', ...
            objectives(j),state,height(cases));
    end
    rows=vertcat(cases_by_state{:});
    water=double(rows.DeliveredDemandFraction);
    joint=double(rows.QualityCompliantDemandFraction);
    assert(height(rows)==2*numel(cfg.design_link_ids) && ...
        all(isfinite([water;joint])) && all(joint<=water+1e-10), ...
        'Balerma combined replay is incomplete');
    worst_count=ceil(0.1*height(rows));
    water_deficit=sort(1-water,'descend');
    joint_deficit=sort(1-joint,'descend');
    all_rows{j}=table(objectives(j),labels(j),height(rows), ...
        mean(water),min(water),mean(joint),min(joint), ...
        nnz(rows.EpanetFallback), ...
        'VariableNames',{'Objective','Topology','FailureCases', ...
        'MeanDeliveredDemandFraction','WorstDeliveredDemandFraction', ...
        'MeanQualityCompliantDemandFraction', ...
        'WorstQualityCompliantDemandFraction','EpanetFallbackCases'});
    all_vulnerability{j}=table(objectives(j),labels(j), ...
        height(rows),worst_count,100*mean(water_deficit(1:worst_count)), ...
        100*mean(joint_deficit(1:worst_count)), ...
        100*mean(water<0.95),100*mean(water-joint), ...
        'VariableNames',{'Objective','Topology','FailureCases', ...
        'WorstTenPercentCount','WorstTenPercentWaterDeficitPct', ...
        'WorstTenPercentJointDeficitPct','Below95WaterPct', ...
        'MeanChlorineOnlyLossPct'});
    all_scenarios{j}=rows;
end
summary=vertcat(all_rows{:});
scenarios=vertcat(all_scenarios{:});
vulnerability=vertcat(all_vulnerability{:});
writetable(summary,fullfile(result_dir,'pda_service_six.csv'));
writetable(scenarios,fullfile(result_dir,'pda_service_scenarios.csv'));
writetable(vulnerability,fullfile(result_dir,'pda_vulnerability_summary.csv'));
end
