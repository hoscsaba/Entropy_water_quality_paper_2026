function full_diameters = apply_design(d, x, cfg, model)
%APPLY_DESIGN Set design diameters while preserving network-specific fixed links.

x = double(x(:)');
if numel(x) ~= numel(model.design_link_indices)
    error('wdn:DesignSize', 'Expected %d design diameters, received %d.', ...
        numel(model.design_link_indices), numel(x));
end
full_diameters = model.original_full_diameters;
full_diameters(model.design_link_indices) = x;

fixed_names = fieldnames(cfg.fixed_link_diameters);
for k = 1:numel(fixed_names)
    full_diameters(model.fixed_link_indices(k)) = ...
        cfg.fixed_link_diameters.(fixed_names{k});
end
d.setLinkDiameter(full_diameters);
end

