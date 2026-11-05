function [ids, diameters] = staci_input_link_template(input_file, staci, diameter_scale)
%STACI_INPUT_LINK_TEMPLATE Original EPANET-order links from the common INP.
% Read once before a GA or post-processing run. STACI also exposes an
% internal fixed-head boundary link for every EPANET reservoir; those are
% deliberately excluded because they are absent from EPANET link results.
lines = splitlines(string(fileread(input_file)));
section = "";
ids = strings(0,1);
diameters = zeros(0,1);
pipe_ids = strings(0,1);
pipe_diameters = zeros(0,1);
pump_ids = strings(0,1);
valve_ids = strings(0,1);
valve_diameters = zeros(0,1);
for k = 1:numel(lines)
    raw = strtrim(extractBefore(lines(k) + ";", ";"));
    if strlength(raw) == 0, continue; end
    if startsWith(raw,"[")
        section = upper(raw);
        continue;
    end
    fields = split(raw);
    fields(fields == "") = [];
    switch section
        case "[PIPES]"
            assert(numel(fields) >= 5, 'Malformed [PIPES] row');
            pipe_ids(end+1,1) = fields(1); %#ok<AGROW>
            pipe_diameters(end+1,1) = str2double(fields(5)); %#ok<AGROW>
        case "[PUMPS]"
            pump_ids(end+1,1) = fields(1); %#ok<AGROW>
        case "[VALVES]"
            assert(numel(fields) >= 5, 'Malformed [VALVES] row');
            valve_ids(end+1,1) = fields(1); %#ok<AGROW>
            valve_diameters(end+1,1) = str2double(fields(4)); %#ok<AGROW>
    end
end
ids = [pipe_ids;pump_ids;valve_ids];
diameters = [pipe_diameters;zeros(numel(pump_ids),1);valve_diameters];
assert(numel(unique(ids)) == numel(ids) && ...
    all(ismember(ids,staci.linkIds())) && all(isfinite(diameters)), ...
    'INP link IDs or diameters do not match the STACI import');
% Cross-check the imported pipe sizes, including unit conversion.
actual_m = double(staci.getLinkProperty(pipe_ids,'diameter_m'));
assert(max(abs(actual_m(:) - pipe_diameters * diameter_scale),[], ...
    'omitnan') < 2e-6, 'STACI and INP pipe diameters differ');
end
