function output_file = write_staci_anytown_outage_input(cfg,input_file,output_file,active_reservoir_ids)
%WRITE_STACI_ANYTOWN_OUTAGE_INPUT Build Anytown's physical-reservoir N-1 INP.
% Nominal optimization replaces reservoirs 65 and 165 with zero-demand
% pressure anchors. Failure replay instead permits them to supply or absorb
% water at the prescribed 215-ft head through fixed links 78 and 80.
% By default both reservoirs are connected. An optional subset of one ID
% closes the other reservoir's sole fixed connector in [STATUS]; it never
% permits both to be disconnected. Give all three reservoirs the same
% 1-mg/L input residual for the controlled water-quality comparison. This
% function only edits INP text; it never changes the nominal optimization file.

assert(strcmp(cfg.id,'anytown'),'Anytown outage input required');
assert(~strcmp(char(input_file),char(output_file)), ...
    'Outage input must not overwrite the nominal optimization input');
anchor_ids = string(cfg.pressure_anchor_node_ids(:));
head_ft = double(cfg.pressure_anchor_target_heads(:));
assert(numel(anchor_ids)==2 && numel(head_ft)==2);
if nargin<4 || isempty(active_reservoir_ids)
    active_reservoir_ids=anchor_ids;
end
active_reservoir_ids=string(active_reservoir_ids(:));
assert(numel(active_reservoir_ids)>=1 && ...
    all(ismember(active_reservoir_ids,anchor_ids)) && ...
    numel(unique(active_reservoir_ids))==numel(active_reservoir_ids), ...
    'Keep at least one physical Anytown reservoir connected');
inactive_ids=setdiff(anchor_ids,active_reservoir_ids);
lines = regexp(fileread(input_file),'\r\n|\n|\r','split');
% Find the fixed connector for each anchor in the nominal network. The
% inactive reservoir remains a fixed-head node but its sole link is closed.
connector_ids=strings(numel(anchor_ids),1);
scan_section="";
for k=1:numel(lines)
    data=strip(regexprep(string(lines{k}),';.*$',''));
    if startsWith(data,'[')
        scan_section=upper(erase(erase(data,'['),']'));
    elseif scan_section=="PIPES" && strlength(data)>0
        tokens=split(data);
        for j=1:numel(anchor_ids)
            if any(tokens(2:3)==anchor_ids(j))
                assert(strlength(connector_ids(j))==0, ...
                    'Anchor has more than one pipe connector');
                connector_ids(j)=tokens(1);
            end
        end
    end
end
assert(all(strlength(connector_ids)>0),'Anchor connector missing');
section = "";
output = strings(0,1);
removed_junction = false(size(anchor_ids));
removed_demand = false(size(anchor_ids));
found_section = struct('reservoirs',false,'quality',false, ...
    'sources',false,'status',false);
for k = 1:numel(lines)
    line = string(lines{k});
    data = strip(regexprep(line,';.*$',''));
    if startsWith(data,'[')
        section = upper(erase(erase(data,'['),']'));
        output(end+1,1) = line; %#ok<AGROW>
        switch section
            case "RESERVOIRS"
                found_section.reservoirs = true;
                for j = 1:numel(anchor_ids)
                    output(end+1,1) = sprintf(' %-8s %.12g', ...
                        anchor_ids(j),head_ft(j)); %#ok<AGROW>
                end
            case "QUALITY"
                found_section.quality = true;
                for j = 1:numel(anchor_ids)
                    output(end+1,1) = sprintf(' %-8s %.12g', ...
                        anchor_ids(j),cfg.source_chlorine); %#ok<AGROW>
                end
            case "SOURCES"
                found_section.sources = true;
                for j = 1:numel(anchor_ids)
                    output(end+1,1) = sprintf(' %-8s CONCEN %.12g', ...
                        anchor_ids(j),cfg.source_chlorine); %#ok<AGROW>
                end
            case "STATUS"
                found_section.status=true;
                for j=1:numel(anchor_ids)
                    if ismember(anchor_ids(j),inactive_ids)
                        output(end+1,1)=sprintf(' %-8s CLOSED', ...
                            connector_ids(j)); %#ok<AGROW>
                    end
                end
        end
        continue
    end
    tokens = split(data);
    if strlength(data)>0 && ismember(section,["JUNCTIONS","DEMANDS"])
        j = find(anchor_ids==tokens(1),1);
        if ~isempty(j)
            if section=="JUNCTIONS", removed_junction(j)=true;
            else, removed_demand(j)=true;
            end
            continue
        end
    end
    output(end+1,1) = line; %#ok<AGROW>
end
assert(all(removed_junction) && all(removed_demand), ...
    'Expected nominal pressure-anchor junctions and zero-demand entries');
assert(all(structfun(@(x)x,found_section)), ...
    'Nominal INP must contain RESERVOIRS, QUALITY, and SOURCES sections');
assert(~any(ismember(anchor_ids,string(cfg.source_node_ids(:)))), ...
    'Pressure anchors already configured as nominal sources');
if ~isfolder(fileparts(output_file)),mkdir(fileparts(output_file));end
fid = fopen(output_file,'w');
assert(fid>0,'Cannot write restored-reservoir outage INP');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
for k = 1:numel(output)
    fprintf(fid,'%s\n',output(k));
end
end
