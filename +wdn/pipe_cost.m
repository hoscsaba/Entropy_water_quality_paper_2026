function value = pipe_cost(diameters, lengths, cfg)
%PIPE_COST Construction cost with network-specific unit conversion.

if isfield(cfg, 'diameter_to_inches')
    diameter_to_inches = cfg.diameter_to_inches;
else
    diameter_to_inches = 0.0393700787; % millimetres to inches
end
if isfield(cfg, 'length_cost_factor')
    length_cost_factor = cfg.length_cost_factor;
else
    length_cost_factor = 1;
end
diameters_in = double(diameters(:)') * diameter_to_inches;
cost_lengths = double(lengths(:)') * length_cost_factor;
value = sum(cfg.cost_coefficient .* diameters_in.^cfg.cost_exponent .* cost_lengths);
end
