function manifest = export_manuscript_tables
%EXPORT_MANUSCRIPT_TABLES Copy the current published numerical CSV sources.
% Exports only the released TT, Anytown and R38-anchor Balerma records.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
output_dir = fullfile(root, 'manuscript', 'generated', 'tables');
if ~isfolder(output_dir), mkdir(output_dir); end

% Only files used to audit the current three-network article are copied.
% The Balerma rows refer to the R38-anchor run, never the older four-source
% or 10--500-mm stages.
tt=fullfile(root,'networks','tanyimboh_templeman', ...
    'results_staci_10_120_clsplit_v2');
anytown=fullfile(root,'networks','anytown','results_staci_anchor_replay');
balerma=fullfile(root,'networks','balerma', ...
    'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
sources = {
    'TT six-design objective matrix',fullfile(tt, ...
        'nominal_six_cross_evaluation.csv'),'tanyimboh_cross_evaluation.csv';
    'TT exact diameters [in]',fullfile(tt, ...
        'optimal_pipe_diameters_six_in.csv'),'tanyimboh_diameters_in.csv';
    'TT PDA service',fullfile(tt, ...
        'pda_service_six.csv'),'tanyimboh_pda_service_six.csv';
    'TT vulnerability',fullfile(tt, ...
        'pda_vulnerability_six.csv'),'tanyimboh_pda_vulnerability_six.csv';
    'Anytown six-design objective matrix',fullfile(anytown, ...
        'cross_evaluation_six.csv'),'anytown_cross_evaluation_six.csv';
    'Anytown exact diameters [in]',fullfile(anytown, ...
        'optimal_pipe_diameters_six_in.csv'),'anytown_diameters_in.csv';
    'Anytown GA stopping records',fullfile(anytown, ...
        'ga_stop_six.csv'),'anytown_ga_stop_six.csv';
    'Anytown 114-case PDA service',fullfile(anytown, ...
        'pda_service_six_pooled.csv'),'anytown_pda_service_six.csv';
    'Anytown vulnerability',fullfile(anytown, ...
        'pda_vulnerability_six_pooled.csv'),'anytown_pda_vulnerability_summary.csv';
    'Anytown ranking capture',fullfile(anytown, ...
        'pda_ranking_capture_six_pooled.csv'),'anytown_pda_ranking_validation.csv';
    'Anytown top-20 pipe rankings',fullfile(anytown, ...
        'pipe_rankings_top20.csv'),'anytown_pipe_rankings_top20.csv';
    'Balerma six-design objective matrix',fullfile(balerma, ...
        'cross_evaluation_six_raw.csv'),'balerma_cross_evaluation_six_raw.csv';
    'Balerma relative objective matrix',fullfile(balerma, ...
        'cross_evaluation_six_relative_to_best.csv'),'balerma_cross_evaluation_six_relative.csv';
    'Balerma exact diameters [in]',fullfile(balerma, ...
        'optimal_pipe_diameters_six_in.csv'),'balerma_optimal_pipe_diameters_six_in.csv';
    'Balerma all-four-reservoir PDA service',fullfile(balerma, ...
        'pda_four_reservoir_protected_summary.csv'),'balerma_pda_all_four_protected_summary.csv';
    'Balerma R38-unavailable PDA service',fullfile(balerma, ...
        'r38_unavailable_protected','summary.csv'),'balerma_pda_r38_unavailable_summary.csv';
    'Balerma top-90 pipe rankings',fullfile(balerma, ...
        'pipe_rankings_top90.csv'),'balerma_pipe_rankings_top90.csv'};

description = strings(size(sources, 1), 1);
source = strings(size(sources, 1), 1);
exported = strings(size(sources, 1), 1);
for k = 1:size(sources, 1)
    description(k) = string(sources{k, 1});
    source(k) = erase(string(sources{k, 2}), string(root) + filesep);
    if ~isfile(sources{k, 2})
        error('paper:MissingTableSource', ...
            'Missing table source: %s', sources{k, 2});
    end
    destination = fullfile(output_dir, sources{k, 3});
    copyfile(sources{k, 2}, destination, 'f');
    exported(k) = erase(string(destination), string(root) + filesep);
end

source = replace(source, filesep, '/');
exported = replace(exported, filesep, '/');

write_tanyimboh_reference_table(output_dir);
manifest = table(description, source, exported);
writetable(manifest, fullfile(output_dir, 'table_source_manifest.csv'));
fprintf('Manuscript table data exported to %s\n', output_dir);
end

function write_tanyimboh_reference_table(output_dir)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root);
verified = wdn.verify_tanyimboh_reference();
link = ["1-3";"1-4";"2-3";"2-4";"3-4";"3-5";"4-6";"5-6";"Entropy S/K"];
case_a_reference = [verified.reference_flows(1,:)';verified.reference_entropy(1)];
case_a_present = [verified.optimized_flows(1,:)';verified.entropy(1)];
case_b_reference = [verified.reference_flows(2,:)';verified.reference_entropy(2)];
case_b_present = [verified.optimized_flows(2,:)';verified.entropy(2)];
values = table(link, case_a_reference, case_a_present, ...
    abs(case_a_reference-case_a_present), case_b_reference, case_b_present, ...
    abs(case_b_reference-case_b_present), 'VariableNames', ...
    {'Link','CaseAReference','CaseAPresent','CaseAAbsoluteDifference', ...
    'CaseBReference','CaseBPresent','CaseBAbsoluteDifference'});
writetable(values, fullfile(output_dir, ...
    'tanyimboh_reference_validation.csv'));
end
