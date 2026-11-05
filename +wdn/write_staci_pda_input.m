function output_file = write_staci_pda_input(cfg, input_file, output_file)
%WRITE_STACI_PDA_INPUT Build a fixed-load EPANET-compatible PDA INP once.
% The generated file is read once by STACI before all outage replays.
content = fileread(input_file);
header = sprintf('[OPTIONS]\n');
assert(count(string(content), "[OPTIONS]") == 1, ...
    'Expected one [OPTIONS] section');
options = sprintf(['[OPTIONS]\n DEMAND MODEL PDA\n' ...
    ' MINIMUM PRESSURE 0\n REQUIRED PRESSURE %.12g\n' ...
    ' PRESSURE EXPONENT 0.5\n'], cfg.minimum_pressure);
content = strrep(content, header, options);
assert(contains(string(content), ' DEMAND MODEL PDA'), ...
    'Failed to insert PDA options');
if ~isfolder(fileparts(output_file)), mkdir(fileparts(output_file)); end
fid = fopen(output_file, 'w');
assert(fid > 0, 'Cannot write PDA input');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, content, 'char');
end
