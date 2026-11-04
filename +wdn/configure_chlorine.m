function configure_chlorine(d, cfg)
%CONFIGURE_CHLORINE Apply network-static EPANET quality settings once.
% Diameter changes do not alter these settings, so repeating hundreds of
% toolkit calls inside every GA fitness evaluation is unnecessary.

d.setTimeSimulationDuration(cfg.quality_duration_hours * 3600);
d.setQualityType('chem', 'Chlorine');
d.setTimeQualityStep(cfg.quality_step_hours * 3600);
d.setTimeReportingStep(cfg.quality_duration_hours * 3600);

for k = 1:double(d.getLinkCount)
    d.setLinkBulkReactionCoeff(k, cfg.bulk_reaction_coefficient);
end

if isfield(cfg, 'source_node_ids') && ~isempty(cfg.source_node_ids)
    node_ids = string(d.getNodeNameID);
    [found_sources, source_nodes] = ...
        ismember(string(cfg.source_node_ids), node_ids);
    if ~all(found_sources)
        error('wdn:UnknownChlorineSource', ...
            'Configured chlorine source node is missing.');
    end
else
    demands_raw = d.getNodeActualDemand;
    if iscell(demands_raw), demands_raw = cell2mat(demands_raw); end
    source_nodes = find(double(demands_raw(:)) < 0);
end

initial_quality = zeros(1, double(d.getNodeCount));
initial_quality(source_nodes) = cfg.source_chlorine;
d.setNodeInitialQuality(initial_quality);
for n = source_nodes(:)'
    d.setNodeSourceType(n, 'CONCEN');
    d.setNodeSourceQuality(n, cfg.source_chlorine);
end
end
