function setup_toolkit(cfg)
%SETUP_TOOLKIT Add the bundled EPANET-MATLAB Toolkit to the current session.

if ~isfolder(cfg.toolkit_dir)
    error('wdn:ToolkitMissing', 'EPANET-MATLAB Toolkit not found: %s', cfg.toolkit_dir);
end
addpath(genpath(cfg.toolkit_dir));
if isfield(cfg, 'toolkit_patch_dir') && isfolder(cfg.toolkit_patch_dir)
    addpath(cfg.toolkit_patch_dir, '-begin');
end
if exist('epanet', 'class') ~= 8 && exist('epanet', 'file') ~= 2
    error('wdn:ToolkitLoadFailed', 'The epanet class is not visible after addpath.');
end
end
