function [d, model] = open_network(cfg)
%OPEN_NETWORK Load one INP file and resolve named design/fixed links.

if ~isfile(cfg.inp_file)
    error('wdn:InpMissing', 'INP file not found: %s', cfg.inp_file);
end
if ~exist(cfg.runtime_dir, 'dir')
    mkdir(cfg.runtime_dir);
end
[~, inp_name, inp_ext] = fileparts(cfg.inp_file);
runtime_inp = fullfile(cfg.runtime_dir, [inp_name inp_ext]);
copyfile(cfg.inp_file, runtime_inp, 'f');

previous_dir = pwd;
directory_cleanup = onCleanup(@() cd(previous_dir));
cd(cfg.runtime_dir);
if isfield(cfg, 'epanet_library') && ~isempty(cfg.epanet_library)
    d = epanet([inp_name inp_ext], cfg.epanet_library);
else
    d = epanet([inp_name inp_ext]);
end

link_ids = string(d.getLinkNameID);
design_ids = string(cfg.design_link_ids);
fixed_ids = string(fieldnames(cfg.fixed_link_diameters));
entropy_excluded_ids = string(cfg.entropy_excluded_link_ids);

[found_design, design_idx] = ismember(design_ids, link_ids);
[found_fixed, fixed_idx] = ismember(fixed_ids, link_ids);
[found_entropy_excluded, entropy_excluded_idx] = ...
    ismember(entropy_excluded_ids, link_ids);
if ~all(found_design)
    error('wdn:UnknownDesignLink', 'Unknown design link(s): %s', ...
        strjoin(design_ids(~found_design), ', '));
end
if ~all(found_fixed)
    error('wdn:UnknownFixedLink', 'Unknown fixed link(s): %s', ...
        strjoin(fixed_ids(~found_fixed), ', '));
end
if ~all(found_entropy_excluded)
    error('wdn:UnknownEntropyLink', 'Unknown entropy-excluded link(s): %s', ...
        strjoin(entropy_excluded_ids(~found_entropy_excluded), ', '));
end
if any(ismember(design_idx, fixed_idx))
    error('wdn:OverlappingLinks', 'A link cannot be both designable and fixed.');
end

model.link_ids = link_ids;
model.design_link_indices = design_idx(:)';
model.fixed_link_indices = fixed_idx(:)';
model.entropy_excluded_link_indices = entropy_excluded_idx(:)';
diameters = d.getLinkDiameter;
lengths = d.getLinkLength;
model.original_full_diameters = double(diameters(:)');
model.link_lengths = double(lengths(:)');
model.node_ids = string(d.getNodeNameID);
model.link_nodes = double(d.getLinkNodesIndex);
model.num_nodes = double(d.getNodeCount);
included_physical_links = true(numel(link_ids), 1);
included_physical_links(model.entropy_excluded_link_indices) = false;
model.physical_link_indices = find(included_physical_links);
model.physical_node_indices = unique( ...
    model.link_nodes(model.physical_link_indices, :));
model.physical_node_mask = false(model.num_nodes, 1);
model.physical_node_mask(model.physical_node_indices) = true;
model.runtime_inp = runtime_inp;

[found_pressure, model.pressure_node_indices] = ...
    ismember(string(cfg.pressure_node_ids), model.node_ids);
[found_quality, model.quality_node_indices] = ...
    ismember(string(cfg.quality_node_ids), model.node_ids);
if ~all(found_pressure) || ~all(found_quality)
    d.unload;
    error('wdn:UnknownNode', 'Configured pressure/quality node ID is missing from the INP file.');
end

model.pressure_anchor_node_indices = [];
if isfield(cfg, 'pressure_anchor_node_ids') && ...
        ~isempty(cfg.pressure_anchor_node_ids)
    [found_anchors, model.pressure_anchor_node_indices] = ...
        ismember(string(cfg.pressure_anchor_node_ids), model.node_ids);
    if ~all(found_anchors)
        d.unload;
        error('wdn:UnknownPressureAnchor', ...
            'Configured pressure-anchor node ID is missing from the INP file.');
    end
    if numel(model.pressure_anchor_node_indices) ~= ...
            numel(cfg.pressure_anchor_target_heads)
        d.unload;
        error('wdn:PressureAnchorSize', ...
            'Pressure-anchor node and target-head counts differ.');
    end
end

for k = 1:numel(fixed_ids)
    expected = cfg.fixed_link_diameters.(char(fixed_ids(k)));
    actual = model.original_full_diameters(fixed_idx(k));
    if abs(actual - expected) > cfg.numeric_tolerance
        d.unload;
        error('wdn:FixedDiameterMismatch', ...
            'Fixed link %s is %.6g in the INP file, expected %.6g.', ...
            fixed_ids(k), actual, expected);
    end
end

% Quality duration, reaction coefficients, initial concentrations, and
% source definitions are invariant during diameter optimization. Configure
% them once here instead of repeating the same toolkit calls in every fitness
% evaluation.
if isfield(cfg, 'quality_duration_hours') && ...
        isfield(cfg, 'source_chlorine')
    wdn.configure_chlorine(d, cfg);
end
end
