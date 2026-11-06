function refine_anytown_anchor_replay_hydraulic_entropy( ...
        paper_root,staci_root,mex_dir)
%REFINE_ANYTOWN_ANCHOR_REPLAY_HYDRAULIC_ENTROPY Cross-seed full GA.
% The refined chlorine-entropy vector improves the earlier hydraulic-
% entropy result. Run the unrestricted hydraulic-entropy GA again with it
% among the in-memory warm starts, retaining the displaced endpoint.
network_dir=fullfile(paper_root,'networks','anytown');
addpath(network_dir);
folder=fullfile(network_dir,'results_staci_anchor_replay');
file=fullfile(folder,'hydraulic_entropy.mat');
archive=fullfile(folder,'hydraulic_entropy_pre_cross_refinement.mat');
assert(isfile(file),'Missing earlier hydraulic endpoint');
assert(~isfile(archive),'Hydraulic refinement has already been run');
source=load(fullfile(folder,'chlorine_entropy.mat'),'result');
old=load(file,'result');
assert(source.result.metrics.hydraulic_entropy> ...
    old.result.metrics.hydraulic_entropy+1e-6, ...
    'Chlorine endpoint does not improve hydraulic entropy');
copyfile(file,archive);
delete(file);
try
    run_anytown_anchor_replay_optimizations( ...
        paper_root,staci_root,mex_dir,"hydraulic_entropy");
    new=load(file,'result');
    assert(new.result.metrics.hydraulic_entropy>= ...
        source.result.metrics.hydraulic_entropy-1e-6, ...
        'Recomputed hydraulic endpoint is inferior to its cross-objective seed');
catch cause
    copyfile(archive,file,'f');
    rethrow(cause);
end
fprintf('Hydraulic entropy: %.9f -> %.9f\n', ...
    old.result.metrics.hydraulic_entropy, ...
    new.result.metrics.hydraulic_entropy);
end
