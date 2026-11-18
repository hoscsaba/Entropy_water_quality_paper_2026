function output_file = write_staci_pda_input(cfg, input_file, output_file, active_reservoir_ids)
%WRITE_STACI_PDA_INPUT Build an EPANET-compatible outage PDA INP once.
% Anytown's nominal pressure anchors become physical fixed-head reservoirs
% before PDA is selected. An optional active-reservoir subset closes one
% connector for compound source-and-pipe failure tests. The generated file
% is read once by STACI.
if strcmp(cfg.id,'anytown')
    if nargin<4, active_reservoir_ids=cfg.pressure_anchor_node_ids; end
    wdn.write_staci_anytown_outage_input(cfg,input_file,output_file, ...
        active_reservoir_ids);
    content = fileread(output_file);
else
    content = fileread(input_file);
end
header = sprintf('[OPTIONS]\n');
assert(count(string(content), "[OPTIONS]") == 1, ...
    'Expected one [OPTIONS] section');
required_pressure = cfg.minimum_pressure;
if strcmp(cfg.id,'anytown')
    required_pressure = required_pressure/(0.3048*cfg.pressure_to_head);
end
options = sprintf(['[OPTIONS]\n DEMAND MODEL PDA\n' ...
    ' MINIMUM PRESSURE 0\n REQUIRED PRESSURE %.12g\n' ...
    ' PRESSURE EXPONENT 0.5\n'], required_pressure);
content = strrep(content, header, options);
% Failure states with nearly isolated branches need more Newton steps than
% the intact benchmark's 40-trial default. This changes only the solver
% iteration ceiling, never the model boundary or accepted tolerance.
content = regexprep(content, '(?m)^(\s*TRIALS\s+)\d+(\s*)$', '$1 200$2');
assert(contains(string(content), ' DEMAND MODEL PDA'), ...
    'Failed to insert PDA options');
if ~isfolder(fileparts(output_file)), mkdir(fileparts(output_file)); end
fid = fopen(output_file, 'w');
assert(fid > 0, 'Cannot write PDA input');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, content, 'char');
end
