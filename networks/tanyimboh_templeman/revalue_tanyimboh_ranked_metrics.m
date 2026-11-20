function revalue_tanyimboh_ranked_metrics(staci_root,mex_dir)
%REVALUE_TANYIMBOH_RANKED_METRICS Strictly score frozen TT subset vectors.
% This is a post hoc audit: it never runs GA or changes any diameter vector.
% TT's 0.1--64 in range permits head losses below STACI's default 1e-4 m
% RMS residual. A fresh 1e-11 m / 1e-12 kg/s solve gives stable flow and
% chlorine cross metrics, including for nearly equal-head source paths.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir=fullfile(root,'networks','tanyimboh_templeman');
addpath(root,network_dir,fullfile(root,'manuscript','figures'), ...
    fullfile(staci_root,'matlab'),mex_dir);
cfg_network=network_config(network_dir);
folder=cfg_network.results_dir;
input_file=cfg_network.inp_file;
objectives={'cost','hydraulic_entropy','branch_hop_weighted_entropy', ...
    'chlorine_concentration','chlorine_entropy','todini'};
files={'ranking_cost_study.mat','ranking_entropy_study.mat', ...
    'ranking_branch_hop_study.mat', ...
    'ranking_chlorine_concentration_study.mat', ...
    'ranking_chlorine_entropy_study.mat','ranking_todini_study.mat'};
fields={'cost_study','entropy_study','branch_study', ...
    'concentration_study','entropy_study','todini_study'};

% Verify every study/cache vector pair before writing any file.
for f=1:numel(files)
    saved=load(fullfile(folder,files{f}));
    study=saved.(fields{f});
    for q=1:numel(study.criterion_keys)
        for j=1:numel(study.k)
            cache_file=fullfile(folder,'ranking_cache',objectives{f}, ...
                study.criterion_keys{q},sprintf('k_%03d.mat',study.k(j)));
            cache=load(cache_file,'entry');
            x=reshape(study.designs(q,j,:),1,[]);
            assert(isequaln(x,double(cache.entry.design_diameters(:)')) ...
                && study.is_feasible(q,j)==cache.entry.is_feasible, ...
                'Saved study/cache mismatch: %s',cache_file);
        end
    end
end

studies=cell(1,numel(files));
for f=1:numel(files)
    path=fullfile(folder,files{f});
    saved=load(path);
    study=saved.(fields{f});
    cfg=saved.cfg;
    cfg.results_dir=folder;
    cfg.figures_dir=cfg_network.figures_dir;
    cfg.ranking.cache_dir=fullfile(folder,'ranking_cache');
    original_designs=study.designs;
    original_optimized=study.metrics(:,:,strcmp(study.metric_names, ...
        objectives{f}));
    for q=1:numel(study.criterion_keys)
        for j=1:numel(study.k)
            cache_file=fullfile(folder,'ranking_cache',objectives{f}, ...
                study.criterion_keys{q},sprintf('k_%03d.mat',study.k(j)));
            cache=load(cache_file,'entry');entry=cache.entry;
            x=reshape(study.designs(q,j,:),1,[]);
            fresh=StaciModel(input_file);
            release=onCleanup(@() fresh.release());
            fresh.setSolverTolerances(1e-11,1e-12);
            [order,original]=wdn.staci_input_link_template( ...
                input_file,fresh,0.001);
            [metrics,violation]=wdn.evaluate_staci_design( ...
                fresh,cfg,x,order,original);
            clear release fresh
            assert(violation<=cfg.ga.constraint_tolerance, ...
                'Strictly scored TT subset is infeasible: %s',cache_file);
            if strcmp(objectives{f},'todini')
                % The optimized Todini scores are numerically stable; keep
                % the released GA objective values exactly as archived.
                metrics.todini=entry.metrics.todini;
            end
            entry.metrics=metrics;
            entry.max_constraint_violation=violation;
            entry.posthoc_scoring='fresh STACI; RMS head 1e-11 m; RMS mass 1e-12 kg/s';
            entry.posthoc_scored_at=datetime('now','TimeZone','local');
            save(cache_file,'entry','-v7');
            study.max_constraint_violations(q,j)=violation;
            for m=1:numel(study.metric_names)
                study.metrics(q,j,m)=metrics.(study.metric_names{m});
            end
            if j==1
                study.original_metrics=metrics;
            end
        end
    end
    assert(isequaln(study.designs,original_designs), ...
        'Revaluation changed a diameter vector');
    if strcmp(objectives{f},'todini')
        assert(isequaln(study.metrics(:,:,strcmp(study.metric_names, ...
            'todini')),original_optimized), ...
            'Revaluation changed a saved Todini objective score');
    end
    study.posthoc_scoring='fresh STACI; RMS head 1e-11 m; RMS mass 1e-12 kg/s';
    study.posthoc_scored_at=datetime('now','TimeZone','local');
    output=struct();output.(fields{f})=study;
    output.ranking=saved.ranking;output.cfg=cfg;
    save(path,'-struct','output','-v7');
    wdn.write_ranking_study_csv(cfg,study, ...
        ['ranking_' objectives{f} '_study.csv']);
    studies{f}=study;
    fprintf('Revalued %s: %d feasible saved vectors\n', ...
        objectives{f},nnz(study.is_feasible));
end
cost_branch_study=studies{1}; %#ok<NASGU>
save(fullfile(folder,'ranking_cost_branch_hop_study.mat'), ...
    'cost_branch_study','-v7');
make_tanyimboh_ranking_matrix(root);
make_tanyimboh_remaining_rankings(root);
end
