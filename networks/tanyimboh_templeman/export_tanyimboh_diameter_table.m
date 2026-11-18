function diameters=export_tanyimboh_diameter_table(paper_root,results_dir)
%EXPORT_TANYIMBOH_DIAMETER_TABLE Exact saved diameters in pipe-ID order.
% Writes native millimeters and converted inches from the six final nominal
% designs; no optimizer or hydraulic solver runs.
if nargin<1 || isempty(paper_root)
    paper_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
network_dir=fullfile(paper_root,'networks','tanyimboh_templeman');
addpath(network_dir,'-begin');
cfg=network_config(network_dir);
folder=fullfile(network_dir,'results_staci_10_120_clsplit_v2');
if nargin>=2 && ~isempty(results_dir),folder=char(results_dir);end
objectives=["cost","hydraulic_entropy","branch_hop_weighted_entropy", ...
    "chlorine_concentration","chlorine_entropy","todini"];
pipe_ids="P"+string((1:8)');
diameters=table(pipe_ids,'VariableNames',{'Pipe'});
[found,order]=ismember(pipe_ids,string(cfg.design_link_ids(:)));
assert(all(found),'The TT design-link IDs do not include P1,...,P8.');
names={'Cost_mm','FlowEntropy_mm','BranchHopEntropy_mm', ...
    'ChlorineConcentration_mm','ChlorineEntropy_mm','Todini_mm'};
for k=1:numel(objectives)
    saved=load(fullfile(folder,objectives(k)+".mat"),'result');
    x=double(saved.result.design_diameters(:));
    assert(numel(x)==8 && all(isfinite(x)) && ...
        all(x>=cfg.minimum_diameter-1e-8) && ...
        all(x<=cfg.maximum_diameter+1e-8), ...
        'Invalid saved TT diameter vector: %s',objectives(k));
    diameters.(names{k})=x(order);
end
writetable(diameters,fullfile(folder,'optimal_pipe_diameters_six.csv'));
inches=diameters;
for k=1:numel(names)
    inches.(names{k})=diameters.(names{k})/25.4;
end
inches.Properties.VariableNames(2:end)=strrep(names,'_mm','_in');
writetable(inches,fullfile(folder,'optimal_pipe_diameters_six_in.csv'));
end
