function ranking=rank_balerma_topological_pipe_outages(paper_root,out_dir)
%RANK_BALERMA_TOPOLOGICAL_PIPE_OUTAGES Count source-disconnected consumers.
% Analyze the fixed INP topology without hydraulic simulation. In each
% availability state, close one eligible nonconnector pipe and count
% positive-demand junctions that lose all paths to the remaining sources.
% Percentages use the 442 original consumers and their total 2453.1 L/s,
% including consumers already disconnected by a source outage. The loss
% reported for a pipe is additional to the source-only state.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','balerma');
cfg=network_config(network_dir);
inp=fullfile(network_dir,'input','network_staci_fixed_load.inp');
[nodes,sources,pipe_ids,from_ids,to_ids,demand]=parse_inp(inp);
assert(numel(nodes)==447 && numel(sources)==4 && ...
    numel(pipe_ids)==454 && nnz(demand>0)==442);
total_demand=sum(demand);
assert(abs(total_demand-2453.1)<1e-6);
all_connectors=["5","338","194","223","188","51"];
assert(all(ismember(all_connectors,pipe_ids)));
eligible=pipe_ids(~ismember(pipe_ids,all_connectors));
assert(numel(eligible)==448);
[ok,from]=ismember(from_ids,nodes);
[ok2,to]=ismember(to_ids,nodes);
assert(all(ok & ok2));
[ok,source_idx]=ismember(sources,nodes);
assert(all(ok));
consumer=demand>0;
states=["all_four","R38_unavailable","R43_unavailable", ...
    "R44_unavailable","R88_unavailable"];
rows=cell(numel(states)*numel(eligible),1);
row=0;
for state=states
    switch state
        case "all_four",disabled=strings(0,1);
        case "R38_unavailable"
            disabled=string(cfg.stress.r38_connector_link_ids(:));
        case "R43_unavailable"
            disabled=string(cfg.stress.r43_connector_link_ids(:));
        case "R44_unavailable"
            disabled=string(cfg.stress.r44_connector_link_ids(:));
        case "R88_unavailable"
            disabled=string(cfg.stress.r88_connector_link_ids(:));
    end
    baseline=source_connected(~ismember(pipe_ids,disabled), ...
        from,to,numel(nodes),source_idx);
    baseline_lost=nnz(consumer & ~baseline);
    for failed=eligible(:)'
        connected=source_connected( ...
            ~ismember(pipe_ids,[disabled;failed]), ...
            from,to,numel(nodes),source_idx);
        newly_lost=consumer & baseline & ~connected;
        count=nnz(newly_lost);
        lost_demand=sum(demand(newly_lost));
        row=row+1;
        rows{row}=table(state,failed,count, ...
            100*count/nnz(consumer),lost_demand, ...
            100*lost_demand/total_demand,baseline_lost, ...
            'VariableNames',{'ReservoirState','FailedPipeID', ...
            'DisconnectedConsumers', ...
            'DisconnectedConsumersPctOfTotal', ...
            'DisconnectedDemandLps', ...
            'DisconnectedDemandPctOfTotal', ...
            'SourceOnlyDisconnectedConsumers'});
    end
end
ranking=vertcat(rows{:});
ranking=sortrows(ranking, ...
    {'ReservoirState','DisconnectedDemandPctOfTotal', ...
    'DisconnectedConsumers','FailedPipeID'}, ...
    {'ascend','descend','descend','ascend'});
if nargin<2 || isempty(out_dir)
    out_dir=fullfile(network_dir, ...
        'results_staci_uniform_0p1_64in_sourceentry_v4', ...
        'reservoir_outage_comparison');
end
if ~isfolder(out_dir),mkdir(out_dir);end
writetable(ranking,fullfile(out_dir, ...
    'topological_pipe_disconnection_ranking.csv'));
for state=states
    subset=ranking(ranking.ReservoirState==state,:);
    fprintf('%s: source-only disconnected %d, top pipe %s: %.2f%% consumers / %.2f%% demand\n', ...
        state,subset.SourceOnlyDisconnectedConsumers(1), ...
        subset.FailedPipeID(1), ...
        subset.DisconnectedConsumersPctOfTotal(1), ...
        subset.DisconnectedDemandPctOfTotal(1));
end
end

function connected=source_connected(active,from,to,n,source_idx)
g=graph(from(active),to(active),[],n);
components=conncomp(g);
connected=ismember(components,components(source_idx));
connected=connected(:);
end

function [nodes,sources,pipe_ids,from_ids,to_ids,demand]=parse_inp(inp)
lines=splitlines(string(fileread(inp)));
section="";
nodes=strings(0,1);sources=strings(0,1);
pipe_ids=strings(0,1);from_ids=strings(0,1);to_ids=strings(0,1);
inline_ids=strings(0,1);inline_demands=zeros(0,1);
demand_ids=strings(0,1);demand_values=zeros(0,1);
for raw=lines(:)'
    line=strtrim(extractBefore(raw+";",";"));
    if strlength(line)==0,continue;end
    if startsWith(line,"["),section=upper(line);continue;end
    t=split(line);
    t=t(strlength(t)>0);
    switch section
        case "[JUNCTIONS]"
            nodes(end+1,1)=t(1); %#ok<AGROW>
            if numel(t)>=3 && isfinite(str2double(t(3)))
                inline_ids(end+1,1)=t(1); %#ok<AGROW>
                inline_demands(end+1,1)=max(str2double(t(3)),0); %#ok<AGROW>
            end
        case "[RESERVOIRS]"
            nodes(end+1,1)=t(1); %#ok<AGROW>
            sources(end+1,1)=t(1); %#ok<AGROW>
        case "[TANKS]"
            nodes(end+1,1)=t(1); %#ok<AGROW>
            sources(end+1,1)=t(1); %#ok<AGROW>
        case {"[PIPES]","[PUMPS]","[VALVES]"}
            pipe_ids(end+1,1)=t(1); %#ok<AGROW>
            from_ids(end+1,1)=t(2); %#ok<AGROW>
            to_ids(end+1,1)=t(3); %#ok<AGROW>
        case "[DEMANDS]"
            demand_ids(end+1,1)=t(1); %#ok<AGROW>
            demand_values(end+1,1)=max(str2double(t(2)),0); %#ok<AGROW>
    end
end
assert(numel(unique(nodes))==numel(nodes));
demand=zeros(numel(nodes),1);
[ok,index]=ismember(inline_ids,nodes);
assert(all(ok));
for k=1:numel(index),demand(index(k))=demand(index(k))+inline_demands(k);end
[ok,index]=ismember(demand_ids,nodes);
assert(all(ok));
for k=1:numel(index),demand(index(k))=demand(index(k))+demand_values(k);end
end
