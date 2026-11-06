function output_file = write_anytown_physical_availability_input( ...
        cfg,input_file,output_file,active_ids,demand_model)
%WRITE_ANYTOWN_PHYSICAL_AVAILABILITY_INPUT One or both basin connectors open.
% Input already has R65 and R165 as 215-ft fixed-head reservoirs. R10 and
% pump 82 always remain. The inactive basin's *sole connector* is closed;
% the reservoir node can remain in the INP without hydraulic exchange.
% For PDA, only EPANET's demand-model options are added. No pressure anchor
% is created. The physical INP and saved diameter vectors are unchanged.

if nargin<5,demand_model="dda";end
active_ids=string(active_ids(:));
demand_model=lower(string(demand_model));
assert(ismember(demand_model,["dda","pda"]));
assert(strcmp(cfg.id,'anytown') && ...
    isempty(cfg.pressure_anchor_node_ids), ...
    'A physical-reservoir Anytown configuration is required');
assert(~strcmp(char(input_file),char(output_file)), ...
    'Do not overwrite the physical source INP');
basin_ids=["65";"165"];
assert(numel(active_ids)>=1 && ...
    numel(unique(active_ids))==numel(active_ids) && ...
    all(ismember(active_ids,basin_ids)), ...
    'At least one auxiliary reservoir must stay connected');
closed_ids=setdiff(basin_ids,active_ids);
lines=regexp(fileread(input_file),'\r\n|\n|\r','split');
section="";
connector=strings(2,1);
basin_head=nan(2,1);
status_seen=false;options_seen=false;
for k=1:numel(lines)
    data=strip(regexprep(string(lines{k}),';.*$',''));
    if startsWith(data,'[')
        section=upper(erase(erase(data,'['),']'));
        status_seen=status_seen || section=="STATUS";
        options_seen=options_seen || section=="OPTIONS";
        continue
    end
    if strlength(data)==0,continue,end
    tokens=split(data);
    if section=="RESERVOIRS"
        for j=1:2
            if tokens(1)==basin_ids(j)
                basin_head(j)=str2double(tokens(2));
            end
        end
    elseif section=="PIPES"
        for j=1:2
            if any(tokens(2:3)==basin_ids(j))
                assert(strlength(connector(j))==0, ...
                    'Reservoir has more than one connector');
                connector(j)=tokens(1);
            end
        end
    end
end
assert(status_seen && options_seen && all(basin_head==215) && ...
    all(strlength(connector)>0), ...
    'Physical reservoir heads or fixed connectors missing');
assert(isequal(sort(connector),sort(["78";"80"])), ...
    'Unexpected reservoir connectors');

section="";output=strings(0,1);
for k=1:numel(lines)
    line=string(lines{k});
    data=strip(regexprep(line,';.*$',''));
    if startsWith(data,'[')
        section=upper(erase(erase(data,'['),']'));
        output(end+1,1)=line; %#ok<AGROW>
        if section=="STATUS"
            for j=1:2
                if ismember(basin_ids(j),closed_ids)
                    output(end+1,1)=sprintf(' %-8s CLOSED', ...
                        connector(j)); %#ok<AGROW>
                end
            end
        elseif section=="OPTIONS" && demand_model=="pda"
            output(end+1,1)=" DEMAND MODEL PDA"; %#ok<AGROW>
            output(end+1,1)=" MINIMUM PRESSURE 0"; %#ok<AGROW>
            output(end+1,1)=sprintf(' REQUIRED PRESSURE %.12g', ...
                cfg.minimum_pressure); %#ok<AGROW>
            output(end+1,1)=" PRESSURE EXPONENT 0.5"; %#ok<AGROW>
        end
        continue
    end
    if section=="STATUS" && strlength(data)>0
        tokens=split(data);
        assert(~ismember(tokens(1),connector), ...
            'Source INP already overrides a basin connector status');
    end
    output(end+1,1)=line; %#ok<AGROW>
end
if ~isfolder(fileparts(output_file)),mkdir(fileparts(output_file));end
fid=fopen(output_file,'w');
assert(fid>0,'Cannot write availability INP');
close_file=onCleanup(@()fclose(fid));
for k=1:numel(output)
    fprintf(fid,'%s\n',output(k));
end
end
