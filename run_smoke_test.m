function run_smoke_test
%RUN_SMOKE_TEST Verify EPANET loading and objective evaluation without optimisation.

root = fileparts(mfilename('fullpath'));
addpath(root);
network_dir = fullfile(root, 'networks', 'tanyimboh_templeman');
addpath(network_dir);
cfg = network_config(network_dir);
wdn.setup_toolkit(cfg);

[d, model] = wdn.open_network(cfg);
cleanup = onCleanup(@() d.unload);
previous_dir = pwd;
cd(cfg.runtime_dir);
directory_cleanup = onCleanup(@() cd(previous_dir));
x = model.original_full_diameters(model.design_link_indices);
metrics = wdn.evaluate_design(d, x, cfg, model);

fprintf('EPANET smoke test passed for %s.\n', cfg.id);
fprintf('Physical pipes: %d; fixed EPANET links: %d.\n', ...
    numel(model.design_link_indices), numel(model.fixed_link_indices));
disp(metrics);
end
