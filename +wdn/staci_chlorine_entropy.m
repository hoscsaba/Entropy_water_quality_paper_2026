function [value, details] = staci_chlorine_entropy(staci, cfg, chlorine_mgL)
%STACI_CHLORINE_ENTROPY Flow entropy weighted by relative source residual.
% Read the imported INP source strengths from the resident STACI model.
% All current benchmarks use equal inputs. A differing-input multisource
% model needs an explicitly defined reference concentration instead.
assert(isfield(cfg,'source_node_ids') && ~isempty(cfg.source_node_ids), ...
    'Source node IDs are required for chlorine normalization');
input_mgL = 1000*double(staci.getNodeProperty( ...
    string(cfg.source_node_ids(:)),'source_concentration_kgm3'));
assert(all(isfinite(input_mgL) & input_mgL>0), ...
    'Input chlorine concentration must be positive');
assert(max(abs(input_mgL-input_mgL(1)))<1e-9, ...
    'Source chlorine concentrations differ; define a common reference');
relative_chlorine = double(chlorine_mgL(:)) / input_mgL(1);
[value, details] = wdn.staci_flow_entropy(staci, cfg, relative_chlorine);
end
