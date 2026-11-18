function summary=run_balerma_r38_unavailable_replay( ...
        paper_root,staci_root,mex_dir)
%RUN_BALERMA_R38_UNAVAILABLE_REPLAY Replay the six saved R38-anchor designs.
% Nominal diameters are fixed. The physical R38 reservoir and its two
% connectors P5/P338 are removed from each PDA failure graph; R43, R44,
% and R88 retain their original fixed heads. Their four direct connectors
% are protected. The same 448 nonconnector pipes fail singly as in the
% all-four-reservoir replay. A source-only baseline separates reservoir
% unavailability from the additional effect of a pipe failure.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
if nargin<2 || isempty(staci_root)
    staci_root='/Users/hoscsaba/Documents/GitHub/staci';
end
if nargin<3 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
network_dir=fullfile(paper_root,'networks','balerma');
addpath(paper_root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg=network_config_r38_anchor(network_dir);
result_dir=cfg.results_dir;
physical=fullfile(network_dir,'input','network_staci_fixed_load.inp');
out_dir=fullfile(result_dir,'r38_unavailable_protected');
if ~isfolder(out_dir),mkdir(out_dir);end
state_cfg=cfg;
state_cfg.results_dir=out_dir;
state_cfg.stress.disabled_link_ids={'5','338'};
state_cfg.stress.require_fixed_head_source=true;
eligible=string(state_cfg.stress.failed_link_ids(:));
protected=string(state_cfg.stress.protected_link_ids(:));
assert(numel(eligible)==448 && isempty(intersect(eligible,protected)));
assert(isequal(sort(protected),sort(["5";"338";"194";"223";"188";"51"])));
pda_file=fullfile(out_dir,'runtime','physical_three_reservoir_pda.inp');
wdn.write_staci_pda_input(state_cfg,physical,pda_file);
probe=fullfile(out_dir,'runtime','r38_boundary_probe.inp');
connected=wdn.write_staci_connected_outage_input( ...
    pda_file,'5',probe,["5";"338"],true);
assert(~ismember("38",connected) && ...
    all(ismember(["43";"44";"88"],connected)), ...
    'R38 was not removed, or a surviving reservoir is disconnected');
base=StaciModel(physical);
requested=max(double(base.getNodeProperty( ...
    string(state_cfg.stress.node_ids(:)),'demand_m3s')),0);
requested=requested(:);
base.release();
assert(sum(requested)>0);
names=string(cfg.objectives(:));
rows=cell(numel(names),1);
all_cases=cell(numel(names),1);
for k=1:numel(names)
    name=names(k);
    saved=load(fullfile(result_dir,name+".mat"),'result');
    assert(strcmp(saved.result.constraint_set_id,cfg.constraint_set_id));
    x=double(saved.result.design_diameters(:));
    cache=fullfile(out_dir,'checkpoints',name+".mat");
    if isfile(cache)
        old=load(cache,'cases','baseline','design_diameters');
        assert(isequal(old.design_diameters,x), ...
            'R38-unavailable checkpoint has another design');
        cases=old.cases;
        baseline=old.baseline;
    else
        started=tic;
        evalc('[~,cases]=wdn.staci_pda_failure_service(state_cfg,x,name,physical,pda_file);');
        cases.EpanetFallback=false(height(cases),1);
        for j=find(cases.Nonconvergent(:))'
            try
                [delivery,pressure,chlorine]= ...
                    wdn.epanet_connected_outage_outputs( ...
                    state_cfg,x,pda_file,cases.FailedLinkID(j), ...
                    state_cfg.stress.node_ids);
                [water,joint,bad]=service_fractions( ...
                    delivery,pressure,chlorine,requested,state_cfg);
                cases.DeliveredDemandFraction(j)=water;
                cases.QualityCompliantDemandFraction(j)=joint;
                cases.PressureViolationFraction(j)=bad;
                cases.Nonconvergent(j)=false;
                cases.EpanetFallback(j)=true;
                cases.ErrorMessage(j)= ...
                    "STACI nonconverged; EPANET PDA/EPS rescue";
            catch exception
                cases.ErrorMessage(j)= ...
                    "STACI and EPANET failed: "+string(exception.message);
            end
        end
        assert(all(~cases.Nonconvergent), ...
            'Incomplete R38-unavailable pipe-failure replay: %s',name);
        try
            [delivery,pressure,chlorine]= ...
                wdn.staci_connected_outage_outputs( ...
                state_cfg,x,pda_file,'5',state_cfg.stress.node_ids,'pda');
            baseline_solver="STACI";
        catch
            [delivery,pressure,chlorine]= ...
                wdn.epanet_connected_outage_outputs( ...
                state_cfg,x,pda_file,'5',state_cfg.stress.node_ids);
            baseline_solver="EPANET PDA/EPS";
        end
        [water,joint,bad]=service_fractions( ...
            delivery,pressure,chlorine,requested,state_cfg);
        baseline=table(water,joint,bad,baseline_solver, ...
            'VariableNames',{'WaterFraction','JointFraction', ...
            'PressureViolationFraction','Solver'});
        folder=fileparts(cache);
        if ~isfolder(folder),mkdir(folder);end
        design_diameters=x; %#ok<NASGU>
        save(cache,'cases','baseline','design_diameters','-v7');
        fprintf('R38 unavailable, %s: 448 cases in %.1f min\n', ...
            name,toc(started)/60);
    end
    assert(height(cases)==448 && ...
        isequal(sort(string(cases.FailedLinkID)),sort(eligible)) && ...
        all(~cases.Nonconvergent), ...
        'Incomplete or incompatible R38-unavailable replay: %s',name);
    water=double(cases.DeliveredDemandFraction);
    chlorine=double(cases.QualityCompliantDemandFraction);
    assert(all(isfinite([water;chlorine])) && ...
        all(water>=0 & water<=1+1e-8) && ...
        all(chlorine>=0 & chlorine<=water+1e-8));
    [worst,wi]=min(water);
    n10=ceil(0.1*numel(water));
    rows{k}=table(name,448,100*baseline.WaterFraction, ...
        100*baseline.JointFraction,100*mean(water),100*worst, ...
        100*mean(mink(water,n10)),100*mean(chlorine), ...
        100*min(chlorine),string(cases.FailedLinkID(wi)), ...
        nnz(cases.EpanetFallback), ...
        'VariableNames',{'Objective','FailureCases', ...
        'SourceOnlyWaterPct','SourceOnlyChlorineCompliantPct', ...
        'MeanWaterPct','WorstWaterPct','WorstTenPercentWaterPct', ...
        'MeanChlorineCompliantPct','WorstChlorineCompliantPct', ...
        'WorstWaterPipeID','EpanetFallbackCases'});
    cases.Objective=repmat(name,height(cases),1);
    all_cases{k}=cases;
    summary=vertcat(rows{1:k});
    writetable(summary,fullfile(out_dir,'summary_partial.csv'));
end
summary=vertcat(rows{:});
writetable(summary,fullfile(out_dir,'summary.csv'));
writetable(vertcat(all_cases{:}),fullfile(out_dir,'cases.csv'));
end

function [water,joint,bad]=service_fractions( ...
        delivery,pressure,chlorine,requested,cfg)
delivery=min(max(double(delivery(:)),0),requested(:));
pressure=double(pressure(:));
chlorine=double(chlorine(:));
assert(numel(delivery)==numel(requested) && ...
    numel(pressure)==numel(requested) && ...
    numel(chlorine)==numel(requested));
water=sum(delivery)/sum(requested);
joint=sum(delivery.*(chlorine>=cfg.stress.minimum_chlorine))/sum(requested);
bad=mean(pressure<cfg.minimum_pressure | pressure>cfg.maximum_pressure);
end
