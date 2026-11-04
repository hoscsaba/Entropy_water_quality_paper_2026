function startup
%STARTUP Add the portable repository code to the MATLAB path.

root = fileparts(mfilename('fullpath'));
addpath(root, '-begin');
addpath(fullfile(root, 'manuscript', 'figures'), '-begin');
addpath(fullfile(root, 'manuscript', 'tables'), '-begin');
addpath(fullfile(root, 'supplementary'), '-begin');

fprintf('Entropy paper repository ready: %s\n', root);
end
