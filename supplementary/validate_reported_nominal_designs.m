function summary = validate_reported_nominal_designs(staci_root, mex_dir, output_dir, max_new_cases, network_filter, paper_root)
%VALIDATE_REPORTED_NOMINAL_DESIGNS Compare every plotted nominal design by ID.
% This independent audit reads the current paper's saved vectors, applies
% each vector to the same fixed-load INP in fresh STACI and EPANET models,
% and records absolute differences and EPANET-side design constraints.
% No optimisation or failure simulation occurs. The default output directory
% is supplementary/results/nominal_design_validation when installed in the
% paper checkout; pass output_dir to write elsewhere.
%
% Example smoke test (two fresh solver calls):
%   validate_reported_nominal_designs(staci_root,mex_dir,fullfile(tempdir,'nominal_audit'),2)
% Resume the same output directory with max_new_cases=Inf for all cases.
% K=0 and infeasible ranked subsets are compared, but do not require a
% feasible pressure/chlorine design. Output checkpoints are written every
% 25 rows and at each network boundary; repeated vectors within a network
% reuse the first independent result.
if nargin<1 || isempty(staci_root), error('Pass the STACI checkout path.'); end
if nargin<2 || isempty(mex_dir)
    mex_dir=fullfile(staci_root,'build-matlab','Matlab');
end
if nargin<6 || isempty(paper_root)
    % When installed in supplementary/, its parent is the paper checkout.
    paper_root=fileparts(fileparts(mfilename('fullpath')));
end
root=char(paper_root);
assert(isfolder(fullfile(root,'networks')) && isfolder(fullfile(root,'supplementary')), ...
    'The validator must be in supplementary/, or paper_root must be passed.');
if nargin<3 || isempty(output_dir)
    output_dir=fullfile(root,'supplementary','results', ...
        'nominal_design_validation');
end
if nargin<4 || isempty(max_new_cases), max_new_cases=Inf; end
if nargin<5 || isempty(network_filter)
    network_filter=["tanyimboh_templeman","anytown","balerma"];
else
    network_filter=string(network_filter);
end
assert(startsWith(string(output_dir),filesep), 'Use an absolute output path.');
assert(max_new_cases>=0,'max_new_cases must be nonnegative.');
addpath(root,fullfile(staci_root,'matlab'),mex_dir,'-begin');
if ~isfolder(output_dir), mkdir(output_dir); end
manifest=build_manifest(root);
signature=['fresh-models-v2-TTstrict:' manifest_hash(manifest)];
checkpoint=fullfile(output_dir,'checkpoint.mat');
if isfile(checkpoint)
    old=load(checkpoint);
    if isfield(old,'manifest')
        assert(isequaln(old.manifest,manifest), ...
            'Saved design vectors or source files changed since checkpoint creation.');
    else
        assert(isfield(old,'signature') && strcmp(old.signature,signature), ...
            'Saved design vectors or source files changed since checkpoint creation.');
    end
    rows=old.rows;
else
    rows=repmat(empty_result(),numel(manifest),1);
end
assert(numel(rows)==numel(manifest),'Checkpoint row count mismatch.');
template=empty_result();
fields=fieldnames(template);
for f=1:numel(fields)
    name=fields{f};
    if ~isfield(rows,name)
        for ii=1:numel(rows), rows(ii).(name)=template.(name); end
    end
end
% Checkpoint rows produced by an earlier validator revision are reclassified
% using the current explicit acceptance rules, without rerunning solvers.
for ii=1:numel(rows)
    if ~ismember(string(rows(ii).status),["pending","error"])
        if isempty(rows(ii).max_flow_link_id)
            % An earlier checkpoint predates link-specific audit columns.
            rows(ii).status='pending';
        else
            rows(ii).status=classify_result(rows(ii),manifest(ii));
        end
    end
end
% Migrate older 76-MB checkpoints into a compact, manifest-hash-verified
% row-only file. The manifest is rebuilt from the source MAT files on resume.
save_checkpoint(checkpoint,signature,rows);
fprintf('Manifest: %d rows, %d already processed.\n',numel(manifest), ...
    sum(string({rows.status})~="pending"));
fresh=0;
dirty=0;
network_names={ 'tanyimboh_templeman','anytown','balerma' };
for nn=1:numel(network_names)
    network=network_names{nn};
    if ~ismember(string(network),network_filter), continue; end
    indices=find(strcmp({manifest.network},network));
    todo=indices(ismember(string({rows(indices).status}),["pending","error"]));
    if isempty(todo), continue; end
    if fresh>=max_new_cases, break; end
    cfg=readonly_config(root,network);
    wdn.setup_toolkit(cfg);
    case_dir=fullfile(output_dir,'cases',network);
    if ~isfolder(case_dir), mkdir(case_dir); end
    input_copy=fullfile(case_dir,'fixed_load.inp');
    copyfile(cfg.inp_file,input_copy,'f');
    old_dir=pwd; cd(case_dir); cd_guard=onCleanup(@()cd(old_dir));
    design_ids=string(cfg.design_link_ids(:));
    cache=containers.Map('KeyType','char','ValueType','double');
    for jj=indices
        if ismember(string(rows(jj).status), ...
                ["ok","compare_only","discrepancy","epanet_infeasible"])
            cache(vector_key(manifest(jj).diameters))=jj;
        end
    end
    for jj=todo
        key=vector_key(manifest(jj).diameters);
        if isKey(cache,key)
            parent=cache(key); rows(jj)=rows(parent);
            rows(jj).case_id=manifest(jj).case_id;
            rows(jj).same_as_case_id=parent;
            rows(jj).status=classify_result(rows(jj),manifest(jj));
            dirty=dirty+1;
            if dirty>=25
                save_checkpoint(checkpoint,signature,rows);
                write_csv(output_dir,root,manifest,rows);dirty=0;
            end
            continue;
        end
        if fresh>=max_new_cases, break; end
        fresh=fresh+1;
        t=tic;
        try
            x=manifest(jj).diameters(:);
            assert(numel(x)==numel(design_ids) && all(isfinite(x)) && all(x>0), ...
                'Invalid or incomplete saved diameter vector.');
            assert(isequal(string(manifest(jj).design_link_ids(:)),design_ids), ...
                'Saved vector design-link ordering differs from the INP.');
            item=compare_fresh(cfg,network,input_copy,manifest(jj));
            item.case_id=jj; item.elapsed_seconds=toc(t);
            item.status=classify_result(item,manifest(jj));
            rows(jj)=item;cache(key)=jj;
            fprintf('%d/%d %s %s: |dH|max %.5g m, |dQ|max %.5g L/s, consumer |dCl|max %.5g mg/L, %s\n', ...
                jj,numel(manifest),network,manifest(jj).source_label, ...
                item.max_abs_head_m,item.max_abs_signed_flow_Lps, ...
                item.max_abs_consumer_chlorine_mgL,item.status);
        catch ME
            item=empty_result();item.case_id=jj;item.status='error';
            item.error_message=sprintf('%s: %s',ME.identifier,ME.message);
            item.elapsed_seconds=toc(t);rows(jj)=item;
            fprintf(2,'%d/%d %s ERROR: %s\n',jj,numel(manifest),network,item.error_message);
        end
        dirty=dirty+1;
        if dirty>=25
            save_checkpoint(checkpoint,signature,rows);
            write_csv(output_dir,root,manifest,rows);dirty=0;
        end
    end
    save_checkpoint(checkpoint,signature,rows);dirty=0;
    write_csv(output_dir,root,manifest,rows);
    clear cd_guard
end
save_checkpoint(checkpoint,signature,rows);
write_csv(output_dir,root,manifest,rows);
summary=struct('manifest_rows',numel(manifest), ...
    'unique_solver_calls_this_invocation',fresh, ...
    'processed_rows',sum(string({rows.status})~="pending"), ...
    'errors',sum(string({rows.status})=="error"), ...
    'discrepancies',sum(string({rows.status})=="discrepancy"), ...
    'epanet_infeasible',sum(string({rows.status})=="epanet_infeasible"), ...
    'checkpoint',checkpoint, ...
    'csv',fullfile(output_dir,'nominal_design_comparison.csv'));
disp(summary)
end

function cfg=readonly_config(root,network)
% The variant wrappers write their derived INPs when called. Read only
% network_config and apply their published boundary choices in memory.
network_dir=fullfile(root,'networks',network);
addpath(network_dir,'-begin'); clear network_config
cfg=network_config(network_dir);
switch network
    case 'tanyimboh_templeman'
        cfg.inp_file=fullfile(network_dir,'input','network_staci_fixed_load.inp');
    case 'anytown'
        cfg.inp_file=fullfile(network_dir,'input','network_anchor_replay.inp');
        cfg.pressure_to_head=2.30787;
    case 'balerma'
        cfg.inp_file=fullfile(network_dir,'input','network_r38_anchor_fixed_load.inp');
        cfg.pressure_anchor_node_ids={'38'};
        cfg.pressure_anchor_target_heads=117/0.3048;
        cfg.pressure_anchor_head_tolerance=0.5;
end
assert(isfile(cfg.inp_file),'Nominal INP missing: %s',cfg.inp_file);
end

function manifest=build_manifest(root)
manifest=repmat(empty_case(),0,1);
networks={'tanyimboh_templeman','anytown','balerma'};
result_folders={'results_staci_10_120_clsplit_v2', ...
    'results_staci_anchor_replay', ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1'};
objectives={'cost','hydraulic_entropy','branch_hop_weighted_entropy', ...
    'chlorine_concentration','chlorine_entropy','todini'};
for n=1:3
    network=networks{n};folder=fullfile(root,'networks',network,result_folders{n});
    % The current figure generator and SM pairwise plots use these exact
    % ranked-study MAT variables, including the refined Anytown Todini.
    switch network
        case 'tanyimboh_templeman'
            rank_files={'ranking_cost_branch_hop_study.mat', ...
                'ranking_entropy_study.mat','ranking_branch_hop_study.mat', ...
                'ranking_chlorine_concentration_study.mat', ...
                'ranking_chlorine_entropy_study.mat','ranking_todini_study.mat'};
            rank_vars={'cost_branch_study','entropy_study','branch_study', ...
                'concentration_study','entropy_study','todini_study'};
        case 'anytown'
            rank_files={'ranking_cost_study.mat', ...
                'ranking_hydraulic_entropy_study.mat', ...
                'ranking_branch_hop_weighted_entropy_study.mat', ...
                'ranking_chlorine_concentration_study.mat', ...
                'ranking_chlorine_entropy_study.mat', ...
                'ranking_todini_refined_study.mat'};
            rank_vars={'study','study','study','study','study','refined'};
        case 'balerma'
            rank_files={'ranking_cost_branch_hop_study.mat', ...
                'ranking_entropy_study.mat','ranking_branch_hop_study.mat', ...
                'ranking_chlorine_concentration_study.mat', ...
                'ranking_chlorine_entropy_study.mat','ranking_todini_study.mat'};
            rank_vars={'cost_branch_study','entropy_study','branch_study', ...
                'concentration_study','entropy_study','todini_study'};
    end
    for o=1:6
        file=fullfile(folder,[objectives{o} '.mat']);
        a=load(file,'result');r=a.result;
        c=empty_case();c.network=network;c.family='final';
        c.objective=objectives{o};c.source_label=objectives{o};
        c.source_file=file;c.source_variable='result';
        c.design_link_ids=cellstr(string(r.design_link_ids(:)));
        c.diameters=double(r.design_diameters(:));
        c.expected_feasible=logical(r.max_constraint_violation<=1e-4);
        c.expected_violation=double(r.max_constraint_violation);
        c=stamp_source(c);c.case_id=numel(manifest)+1;
        manifest(end+1,1)=c; %#ok<AGROW>
    end
    for o=1:6
        file=fullfile(folder,rank_files{o});
        a=load(file,rank_vars{o});s=a.(rank_vars{o});
        assert(isfield(s,'designs') && ndims(s.designs)==3, ...
            'Ranked-study file does not contain plotted diameter vectors: %s',file);
        assert(size(s.designs,1)==numel(s.criterion_keys) && ...
            size(s.designs,2)==numel(s.k),'Ranking dimensions mismatch.');
        c=empty_case();c.network=network;c.family='ranking';
        c.objective=objectives{o};c.source_file=file;
        c.source_variable=rank_vars{o};c=stamp_source(c);
        final=load(fullfile(folder,[objectives{o} '.mat']),'result');
        c.design_link_ids=cellstr(string(final.result.design_link_ids(:)));
        assert(size(s.designs,3)==numel(c.design_link_ids), ...
            'Ranking vector length differs from the final design.');
        for q=1:numel(s.criterion_keys)
            for j=1:numel(s.k)
                row=c;row.criterion=char(string(s.criterion_keys{q}));
                row.k=double(s.k(j));row.ranking_index=q;row.source_row=j;
                row.diameters=squeeze(double(s.designs(q,j,:)));
                row.expected_feasible=logical(s.is_feasible(q,j));
                row.expected_violation=double(s.max_constraint_violations(q,j));
                row.source_label=sprintf('%s/%s/K%d',objectives{o}, ...
                    row.criterion,row.k);
                row.case_id=numel(manifest)+1;manifest(end+1,1)=row; %#ok<AGROW>
            end
        end
    end
    if n<3
        if n==1
            file=fullfile(folder,'pareto_cost_branch_hop.mat');var='result';
        else
            file=fullfile(folder,'pareto_plot_archive.mat');var='plot_result';
        end
        a=load(file,var);s=a.(var);indices=1:size(s.designs,1);
    else
        study=fullfile(folder,'pareto_r38_unavailable_study');
        file=fullfile(study,'pareto_cost_branch_hop_top90.mat');var='result';
        a=load(file,var);s=a.(var);
        selected=readtable(fullfile(study,'pareto_selected20_indices.csv'));
        indices=double(selected.ArchiveIndex(:)');
        assert(numel(indices)==20 && numel(unique(indices))==20, ...
            'Balerma S25 selected-index list is not 20 unique rows.');
    end
    final=load(fullfile(folder,'cost.mat'),'result');
    ids=cellstr(string(final.result.design_link_ids(:)));
    assert(size(s.designs,2)==numel(ids) && ...
        all(indices>=1) && all(indices<=size(s.designs,1)), ...
        'Pareto archive does not match design-link count or selected indices.');
    for ix=indices
        c=empty_case();c.network=network;c.family='pareto';
        c.objective='cost_vs_branch_hop';
        c.source_label=sprintf('archive/%d',ix);c.source_file=file;
        c.source_variable=var;c.source_row=ix;c.archive_index=ix;
        c.design_link_ids=ids;c.diameters=double(s.designs(ix,:))';
        c.expected_feasible=true;c.expected_violation=NaN;
        c=stamp_source(c);c.case_id=numel(manifest)+1;
        manifest(end+1,1)=c; %#ok<AGROW>
    end
end
assert(numel(manifest)==1369,'Unexpected count of reported nominal vectors.');
end

function r=compare_fresh(cfg,network,input_copy,c)
% Construct both engines from the same unmodified INP for every distinct
% diameter vector. This prevents warm hydraulic states from changing flow
% splits on nearly zero-head-loss loops when solver tolerances are finite.
if isfield(cfg,'epanet_library') && strlength(string(cfg.epanet_library))>0
    ep=epanet('fixed_load.inp',cfg.epanet_library);
else
    ep=epanet('fixed_load.inp');
end
ep_guard=onCleanup(@()ep.unload());
st=StaciModel(input_copy);
st_guard=onCleanup(@()st.release());
if strcmp(network,'tanyimboh_templeman')
    % The reported TT re-evaluations use a tight Newton residual because
    % large diameters create head losses near floating-point resolution.
    st.setSolverTolerances(1e-11,1e-12);
end
ep_nodes=string(ep.getNodeNameID);ep_nodes=ep_nodes(:);
ep_links=string(ep.getLinkNameID);ep_links=ep_links(:);
design_ids=string(cfg.design_link_ids(:));
[found,di]=ismember(design_ids,ep_links);
assert(all(found) && numel(unique(di))==numel(di), ...
    '%s: design-link IDs do not match the INP.',network);
x=c.diameters(:);
assert(isequal(string(c.design_link_ids(:)),design_ids), ...
    'Saved vector design-link ordering differs from the INP.');
d=double(ep.getLinkDiameter);d=d(:);d(di)=x;
ep.setLinkDiameter(d);
if strcmp(network,'anytown'), diameter_scale=0.0254;
else, diameter_scale=0.001; end
st.setLinkProperty(design_ids,'diameter_m',x*diameter_scale);
r=compare_one(ep,st,cfg,network,ep_nodes,ep_links,c);
r.fresh_model=1;
clear st_guard ep_guard st ep
end

function r=compare_one(ep,st,cfg,network,ep_nodes,ep_links,c)
r=empty_result();
ep.solveCompleteHydraulics;
eh=double(ep.getNodeHydraulicHead);eh=eh(:);
ep_pressure=double(ep.getNodePressure);ep_pressure=ep_pressure(:);
eq=double(ep.getLinkFlows);eq=eq(:);
ep.solveCompleteQuality;
ec=double(ep.getNodeActualQuality);ec=ec(:);
status=st.solveHydraulics();
assert(status.converged,'STACI hydraulics did not converge.');
sn=st.nodeResults();sl=st.linkResults();
sq=st.solveSteadyQuality('chemical');
[nf,ni]=ismember(ep_nodes,string(sn.id(:)));
[lf,li]=ismember(ep_links,string(sl.id(:)));
[qf,qi]=ismember(ep_nodes,string(sq.node_ids(:)));
assert(all(nf) && all(lf) && all(qf),'STACI/EPANET IDs do not match.');
switch network
    case 'anytown'
        head_scale=0.3048;flow_scale=6.30901964e-5;
        ep_pressure=ep_pressure*0.3048*cfg.pressure_to_head;
    case 'tanyimboh_templeman'
        head_scale=1;flow_scale=1/3600;
    otherwise
        head_scale=1;flow_scale=0.001;
end
dh=abs(eh*head_scale-double(sn.total_head_m(ni)));
dq=abs(eq*flow_scale-double(sl.flow_rate_m3s(li)))*1000;
dc=abs(ec-1000*double(sq.node_concentration_kgm3(qi)));
assert(all(isfinite([dh;dq;dc])),'Non-finite engine comparison.');
threshold=pi/4*0.010^2*0.01;
consumer=double(sn.demand_m3s(ni))>threshold;
consumer=consumer & ismember(ep_nodes,string(cfg.quality_node_ids(:)));
assert(any(consumer),'No qualifying consumer nodes.');
[pf,pressure_idx]=ismember(string(cfg.pressure_node_ids(:)),ep_nodes);
assert(all(pf),'Pressure assessment node missing.');
pressure_violation=max([0;cfg.minimum_pressure-ep_pressure(pressure_idx); ...
    ep_pressure(pressure_idx)-cfg.maximum_pressure]);
if strcmp(network,'anytown')
    [af,ai]=ismember(string(cfg.pressure_anchor_node_ids(:)),ep_nodes);
    assert(all(af),'Anytown pressure anchor missing.');
    anchor_error=max(abs(eh(ai)-double(cfg.pressure_anchor_target_heads(:))));
    anchor_tolerance=cfg.pressure_anchor_head_tolerance;
    [cf,ci]=ismember(["78";"80"],ep_links);
    assert(all(cf),'Anytown zero-flow anchor connectors missing.');
    r.max_anchor_connector_flow_Lps=max(abs(eq(ci))*flow_scale)*1000;
elseif strcmp(network,'balerma')
    ai=find(ep_nodes=="38",1);assert(~isempty(ai),'R38 anchor missing.');
    anchor_error=abs(eh(ai)/0.3048-cfg.pressure_anchor_target_heads);
    anchor_tolerance=cfg.pressure_anchor_head_tolerance;
else
    anchor_error=0;anchor_tolerance=Inf;
end
r.node_count=numel(dh);r.link_count=numel(dq);
r.consumer_count=sum(consumer);
r.max_abs_head_m=max(dh);r.mean_abs_head_m=mean(dh);
r.max_abs_signed_flow_Lps=max(dq);r.mean_abs_signed_flow_Lps=mean(dq);
[~,ih]=max(dh);[~,il]=max(dq);
r.max_head_node_id=char(ep_nodes(ih));
r.epanet_head_at_max_m=eh(ih)*head_scale;
r.staci_head_at_max_m=double(sn.total_head_m(ni(ih)));
r.max_flow_link_id=char(ep_links(il));
r.epanet_flow_at_max_Lps=eq(il)*flow_scale*1000;
r.staci_flow_at_max_Lps=double(sl.flow_rate_m3s(li(il)))*1000;
r.max_abs_chlorine_mgL=max(dc);r.mean_abs_chlorine_mgL=mean(dc);
r.max_abs_consumer_chlorine_mgL=max(dc(consumer));
r.mean_abs_consumer_chlorine_mgL=mean(dc(consumer));
r.min_epanet_consumer_chlorine_mgL=min(ec(consumer));
r.epanet_pressure_violation_m=pressure_violation;
r.epanet_chlorine_violation_mgL=max(0,0.2-r.min_epanet_consumer_chlorine_mgL);
r.anchor_head_error_ft=anchor_error;
r.epanet_anchor_violation_ft=max(0,anchor_error-anchor_tolerance);
r.diameter_bound_violation=max([0;cfg.minimum_diameter-c.diameters(:); ...
    c.diameters(:)-cfg.maximum_diameter]);
% This is a numerical agreement flag, not an assertion of design
% feasibility. The all-node chlorine maximum is reported separately because
% stagnant zero-demand nodes may be undefined in steady quality.
r.hydraulic_agreement=double(r.max_abs_head_m<=0.1 && ...
    r.max_abs_signed_flow_Lps<=0.01);
r.consumer_chlorine_agreement=double( ...
    r.max_abs_consumer_chlorine_mgL<=0.01);
r.epanet_feasible=double(pressure_violation<=1e-4 && ...
    r.epanet_chlorine_violation_mgL<=1e-4 && ...
    r.epanet_anchor_violation_ft<=1e-4 && ...
    r.diameter_bound_violation<=1e-6);
% Classification is done by classify_result after both engines return.
end

function status=classify_result(r,c)
if r.hydraulic_agreement~=1 || r.consumer_chlorine_agreement~=1
    status='discrepancy';
elseif c.expected_feasible && r.epanet_feasible~=1
    status='epanet_infeasible';
elseif ~c.expected_feasible
    status='compare_only';
else
    status='ok';
end
end

function c=empty_case()
c=struct('case_id',0,'network','','family','','objective','', ...
    'criterion','','k',NaN,'ranking_index',NaN,'archive_index',NaN, ...
    'source_row',NaN,'source_label','','source_file','', ...
    'source_variable','','source_bytes',NaN,'source_datenum',NaN, ...
    'design_link_ids',{{}},'diameters',[],'expected_feasible',false, ...
    'expected_violation',NaN);
end

function c=stamp_source(c)
d=dir(c.source_file);assert(numel(d)==1,'Source MAT file missing.');
c.source_bytes=d.bytes;c.source_datenum=d.datenum;
end

function r=empty_result()
r=struct('case_id',0,'status','pending','same_as_case_id',0, ...
    'error_message','','elapsed_seconds',NaN,'fresh_model',NaN, ...
    'node_count',NaN,'link_count',NaN,'consumer_count',NaN, ...
    'max_abs_head_m',NaN,'mean_abs_head_m',NaN, ...
    'max_head_node_id','','epanet_head_at_max_m',NaN, ...
    'staci_head_at_max_m',NaN, ...
    'max_abs_signed_flow_Lps',NaN,'mean_abs_signed_flow_Lps',NaN, ...
    'max_flow_link_id','','epanet_flow_at_max_Lps',NaN, ...
    'staci_flow_at_max_Lps',NaN, ...
    'max_abs_chlorine_mgL',NaN,'mean_abs_chlorine_mgL',NaN, ...
    'max_abs_consumer_chlorine_mgL',NaN, ...
    'mean_abs_consumer_chlorine_mgL',NaN, ...
    'min_epanet_consumer_chlorine_mgL',NaN, ...
    'epanet_pressure_violation_m',NaN, ...
    'epanet_chlorine_violation_mgL',NaN, ...
    'anchor_head_error_ft',NaN, ...
    'epanet_anchor_violation_ft',NaN, ...
    'max_anchor_connector_flow_Lps',NaN, ...
    'diameter_bound_violation',NaN, ...
    'hydraulic_agreement',NaN, ...
    'consumer_chlorine_agreement',NaN,'epanet_feasible',NaN);
end

function key=vector_key(x)
key=sprintf('%.17g,',double(x(:)));
end

function save_checkpoint(file,signature,rows)
temporary=[file '.new.mat'];
save(temporary,'signature','rows','-v7');
movefile(temporary,file,'f');
end

function signature=manifest_hash(manifest)
md=java.security.MessageDigest.getInstance('SHA-256');
md.update(uint8(jsonencode(manifest)));
signature=lower(reshape(dec2hex(typecast(int8(md.digest()),'uint8'),2)',1,[]));
end

function write_csv(output_dir,root,manifest,rows)
source_paths=string({manifest.source_file})';
prefix=string(root)+filesep;
assert(all(startsWith(source_paths,prefix)), ...
    'Source MAT outside the paper checkout.');
relative_paths=extractAfter(source_paths,strlength(prefix));
t=table((1:numel(manifest))',string({manifest.network})', ...
    string({manifest.family})',string({manifest.objective})', ...
    string({manifest.criterion})',[manifest.k]',[manifest.archive_index]', ...
    string({manifest.source_label})',relative_paths, ...
    [manifest.expected_feasible]',[manifest.expected_violation]', ...
    string({rows.status})',[rows.same_as_case_id]', ...
    string({rows.error_message})',[rows.elapsed_seconds]', ...
    [rows.fresh_model]', ...
    [rows.max_abs_head_m]',[rows.mean_abs_head_m]', ...
    string({rows.max_head_node_id})',[rows.epanet_head_at_max_m]', ...
    [rows.staci_head_at_max_m]', ...
    [rows.max_abs_signed_flow_Lps]',[rows.mean_abs_signed_flow_Lps]', ...
    string({rows.max_flow_link_id})',[rows.epanet_flow_at_max_Lps]', ...
    [rows.staci_flow_at_max_Lps]', ...
    [rows.max_abs_chlorine_mgL]',[rows.mean_abs_chlorine_mgL]', ...
    [rows.max_abs_consumer_chlorine_mgL]', ...
    [rows.mean_abs_consumer_chlorine_mgL]', ...
    [rows.min_epanet_consumer_chlorine_mgL]', ...
    [rows.epanet_pressure_violation_m]', ...
    [rows.epanet_chlorine_violation_mgL]', ...
    [rows.anchor_head_error_ft]',[rows.epanet_anchor_violation_ft]', ...
    [rows.max_anchor_connector_flow_Lps]', ...
    [rows.diameter_bound_violation]', ...
    [rows.hydraulic_agreement]',[rows.consumer_chlorine_agreement]', ...
    [rows.epanet_feasible]', ...
    'VariableNames',{'CaseID','Network','Family','Objective', ...
    'RankingCriterion','K','ArchiveIndex','SourceLabel','SourceMAT', ...
    'SavedFeasible','SavedConstraintViolation','Status','SameAsCaseID', ...
    'Error','ElapsedSeconds','FreshModel','MaxAbsHead_m','MeanAbsHead_m', ...
    'MaxHeadNodeID','EPANETHeadAtMax_m','STACIHeadAtMax_m', ...
    'MaxAbsSignedFlow_Lps','MeanAbsSignedFlow_Lps', ...
    'MaxFlowLinkID','EPANETFlowAtMax_Lps','STACIFlowAtMax_Lps', ...
    'MaxAbsChlorine_mgL','MeanAbsChlorine_mgL', ...
    'MaxAbsConsumerChlorine_mgL','MeanAbsConsumerChlorine_mgL', ...
    'MinEPANETConsumerChlorine_mgL','EPANETPressureViolation_m', ...
    'EPANETChlorineViolation_mgL','AnchorHeadError_ft', ...
    'EPANETAnchorViolation_ft','MaxAnchorConnectorFlow_Lps', ...
    'DiameterBoundViolation','HydraulicAgreement', ...
    'ConsumerChlorineAgreement','EPANETFeasible'});
writetable(t,fullfile(output_dir,'nominal_design_comparison.csv'));
end
