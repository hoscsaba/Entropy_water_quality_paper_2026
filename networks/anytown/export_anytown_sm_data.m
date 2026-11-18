function [diameter_table, ranking_table] = export_anytown_sm_data(paper_root)
%EXPORT_ANYTOWN_SM_DATA Export exact saved Anytown SM diameter/ranking data.
% Reads saved MAT files only. No GA, hydraulic, chlorine, or PDA solve runs.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
folder=fullfile(paper_root,'networks','anytown', ...
    'results_staci_anchor_replay');
objectives={'cost','hydraulic_entropy','branch_hop_weighted_entropy', ...
    'chlorine_concentration','chlorine_entropy','todini'};
labels={'Cost','FlowEntropy','BranchHopEntropy', ...
    'ChlorineConcentration','ChlorineEntropy','Todini'};
ids=string((2:2:76)');
values=zeros(numel(ids),numel(objectives));
for k=1:numel(objectives)
    saved=load(fullfile(folder,[objectives{k} '.mat']),'result');
    r=saved.result;
    assert(strcmp(r.constraint_set_id, ...
        'pressure_10_120m_chlorine_mass_split_v2') && ...
        r.minimum_diameter==0.1 && r.maximum_diameter==64, ...
        'Saved Anytown result uses different nominal constraints');
    assert(isequal(string(r.design_link_ids(:)),ids), ...
        'Saved result pipe order differs from the 38-pipe model');
    values(:,k)=double(r.design_diameters(:));
end
diameter_table=table("P"+ids,'VariableNames',{'PipeID'});
for k=1:numel(labels)
    diameter_table.(labels{k})=values(:,k);
end
writetable(diameter_table,fullfile(folder, ...
    'optimal_pipe_diameters_six_in.csv'));
saved=load(fullfile(folder,'pipe_rankings.mat'),'ranking');
rank=saved.ranking;
ordered=string(rank.ordered_link_ids);
assert(isequal(size(ordered),[38,5]), ...
    'Saved Anytown ranking order must be 38 by 5');
ranking_table=table((1:38)','VariableNames',{'Rank'});
rank_labels={'FlowRate','PressureSensitivity','NodalEntropy', ...
    'EntropySensitivity','Volume'};
for k=1:numel(rank_labels)
    ranking_table.(rank_labels{k})="P"+ordered(:,k);
end
ranking_table.ReleasedPercent=100*ranking_table.Rank/38;
writetable(ranking_table,fullfile(folder,'pipe_rankings_full38.csv'));
end
