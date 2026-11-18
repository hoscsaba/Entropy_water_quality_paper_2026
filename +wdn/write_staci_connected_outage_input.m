function connected_ids = write_staci_connected_outage_input( ...
        input_file, failed_link_id, output_file, removed_link_ids, ...
        require_fixed_head_source)
%WRITE_STACI_CONNECTED_OUTAGE_INPUT Remove source-disconnected islands.
% A closed bridge makes the STACI Newton matrix singular because an isolated
% component has no reference head. Such components receive zero delivery and
% zero chlorine in the calling outage metric. The source-connected network
% is solved by STACI without changing any surviving pipe or source data.
lines = regexp(fileread(input_file), '\r\n|\n|\r', 'split');
if nargin<4,removed_link_ids=strings(0,1);end
if nargin<5,require_fixed_head_source=false;end
sections = strings(numel(lines),1);
section = "";
junctions = strings(0,1); sources = strings(0,1);
demand_nodes = strings(0,1);
link_ids = strings(0,1); from_ids = strings(0,1); to_ids = strings(0,1);
closed_ids = strings(0,1);
tokens = cell(numel(lines),1);
for k = 1:numel(lines)
    line = strtrim(regexprep(lines{k}, ';.*$', ''));
    if startsWith(line,'[')
        section = upper(extractBetween(string(line),'[',']'));
        if isempty(section), section = ""; end
        sections(k) = section;
        continue;
    end
    sections(k) = section;
    if isempty(line), continue; end
    t = string(strsplit(line)); tokens{k} = t;
    switch section
        case "JUNCTIONS"
            junctions(end+1,1) = t(1); %#ok<AGROW>
        case "RESERVOIRS"
            sources(end+1,1) = t(1); %#ok<AGROW>
        case "TANKS"
            sources(end+1,1) = t(1); %#ok<AGROW>
        case {"PIPES","PUMPS","VALVES"}
            link_ids(end+1,1) = t(1); %#ok<AGROW>
            from_ids(end+1,1) = t(2); %#ok<AGROW>
            to_ids(end+1,1) = t(3); %#ok<AGROW>
            if section=="PIPES" && numel(t)>=8 && strcmpi(t(8),"CLOSED")
                closed_ids(end+1,1)=t(1); %#ok<AGROW>
            end
        case "DEMANDS"
            if numel(t)>=2 && str2double(t(2))<0 && ...
                    ~require_fixed_head_source
                sources(end+1,1)=t(1); %#ok<AGROW>
            elseif numel(t)>=2 && str2double(t(2))>0
                demand_nodes(end+1,1)=t(1); %#ok<AGROW>
            end
        case "STATUS"
            if numel(t)>=2 && strcmpi(t(2),"CLOSED")
                closed_ids(end+1,1)=t(1); %#ok<AGROW>
            end
    end
end
assert(any(link_ids == string(failed_link_id)), 'Unknown failed pipe');
all_nodes = unique([junctions;sources],'stable');
[ok1, from] = ismember(from_ids,all_nodes);
[ok2, to] = ismember(to_ids,all_nodes);
assert(all(ok1 & ok2), 'Pipe endpoint missing from input');
active = link_ids ~= string(failed_link_id) & ...
    ~ismember(link_ids,[closed_ids;string(removed_link_ids(:))]);
g = graph(from(active),to(active),[],cellstr(all_nodes));
components = conncomp(g);
[ok_source, source_index] = ismember(sources,all_nodes);
assert(all(ok_source),'Source missing from graph');
[ok_demand,demand_index]=ismember(demand_nodes,all_nodes);
assert(all(ok_demand),'Consumer missing from outage graph');
% TT requires a physical fixed-head source in every retained component.
% Its node-2 fixed inflow alone cannot define absolute pressure: remove
% that entire component and let the caller count its demand as unserved.
% With the default policy, existing source handling is preserved.
service_components=intersect(unique(components(source_index)), ...
    unique(components(demand_index)));
connected = ismember(components,service_components);
connected = connected(:);
connected_ids = all_nodes(connected);
keep_links = active & connected(from) & connected(to);
kept_ids = link_ids(keep_links);
kept_sections = ["TITLE","JUNCTIONS","RESERVOIRS","TANKS", ...
    "PIPES","PUMPS","VALVES","STATUS", ...
    "DEMANDS","EMITTERS","PATTERNS","CURVES","CONTROLS", ...
    "RULES","QUALITY","SOURCES","MIXING","REACTIONS", ...
    "TIMES","OPTIONS","COORDINATES","END"];
if ~isfolder(fileparts(output_file)), mkdir(fileparts(output_file)); end
fid = fopen(output_file,'w');
assert(fid > 0, 'Cannot create outage INP');
file_cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
for k = 1:numel(lines)
    sec = sections(k);
    if ~ismember(sec,kept_sections), continue; end
    t = tokens{k};
    if ~isempty(t)
        switch sec
            case {"JUNCTIONS","RESERVOIRS","TANKS","DEMANDS","QUALITY", ...
                  "SOURCES","COORDINATES"}
                if ~ismember(t(1),connected_ids), continue; end
            case {"PIPES","PUMPS","VALVES","STATUS"}
                if ~ismember(t(1),kept_ids), continue; end
            case "REACTIONS"
                if numel(t)>=2 && strcmpi(t(1),'PIPE') && ...
                        ~ismember(t(2),kept_ids), continue; end
        end
        if sec == "OPTIONS" && strcmpi(t(1),'TRIALS')
            % Bridge outages can require more Newton steps in PDA. This
            % changes only the solver budget, not the physical network.
            fprintf(fid,' TRIALS              200\n');
            continue;
        end
    end
    fprintf(fid,'%s\n',lines{k});
end
end
