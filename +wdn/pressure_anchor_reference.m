function x_ref = pressure_anchor_reference(cfg, model)
%PRESSURE_ANCHOR_REFERENCE Return the documented feasible Anytown reference.

x0 = model.original_full_diameters(model.design_link_indices);
ub = cfg.maximum_diameter * ones(size(x0));
x_ref = x0 + cfg.ga.feasible_interpolation_to_upper * (ub - x0);
end
