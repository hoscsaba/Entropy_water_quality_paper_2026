function verify_balerma_island_handling(staci_root,mex_dir)
%VERIFY_BALERMA_ISLAND_HANDLING Regression for STACI N-1 PDA quality replay.
% Pipe 1 disconnects a node from every reservoir; pipe 4 leaves a
% source-connected PDA node with zero delivered demand and no inflow.
root = fileparts(fileparts(mfilename('fullpath')));
network_dir = fullfile(root,'networks','balerma');
addpath(root,network_dir,fullfile(staci_root,'matlab'),mex_dir);
cfg = network_config(network_dir);
input_file = fullfile(network_dir,'input','network_staci_fixed_load.inp');
pda_file = fullfile(cfg.results_dir,'runtime','network_pda_fixed_load.inp');
wdn.write_staci_pda_input(cfg,input_file,pda_file);
saved = load(fullfile(cfg.results_dir,'cost.mat'),'result');
nodes = string(cfg.stress.node_ids(:));
for failed = ["1","4"]
    [demand,pressure,chlorine] = wdn.staci_connected_outage_outputs( ...
        cfg,saved.result.design_diameters,pda_file,failed,nodes,'pda');
    assert(all(isfinite(demand)) && all(demand >= 0));
    assert(all(isfinite(chlorine)) && all(chlorine >= 0));
    assert(all(isfinite(pressure) | isinf(pressure)));
    assert(sum(demand) > 0 && sum(demand) < 1.103895);
    if failed == "1"
        assert(any(isinf(pressure)),'The source-disconnected island was lost');
    end
    fprintf('Balerma pipe %s: delivered %.9g m3/s, %d isolated nodes\n', ...
        failed,sum(demand),nnz(isinf(pressure)));
end
end
