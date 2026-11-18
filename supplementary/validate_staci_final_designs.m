function comparison = validate_staci_final_designs(staci_root, mex_dir, output_dir, networks, objective_filter, anytown_variant, result_dir_override)
%VALIDATE_STACI_FINAL_DESIGNS Independent EPANET 2.2 replay of saved optima.
% Each exact saved diameter vector is applied to identical 14-day fixed-load
% INPs in both engines. EPANET is used here only for independent verification.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 3 || isempty(output_dir)
    output_dir = fullfile(root, 'supplementary', 'results', 'validation_current');
end
if ~startsWith(string(output_dir), filesep)
    output_dir = fullfile(pwd, output_dir);
end
addpath(root, fullfile(staci_root, 'matlab'), mex_dir);
if ~isfolder(output_dir), mkdir(output_dir); end
if nargin < 4 || isempty(networks)
    networks = ["tanyimboh_templeman","anytown","balerma"];
else
    networks = string(networks);
end
if nargin < 5, objective_filter = []; end
if nargin < 6, anytown_variant = "anchor_replay"; end
if nargin < 7, result_dir_override = []; end
rows = cell(0, 19);
row = 0;
for network = networks
    network_dir = char(fullfile(root, 'networks', network));
    addpath(network_dir,'-begin');
    clear network_config
    if network == "anytown" && string(anytown_variant) == "anchor_replay"
        cfg = network_config_anchor_replay(network_dir);
        input_file = cfg.inp_file;
    elseif network == "anytown" && string(anytown_variant) == "physical_reservoirs"
        cfg = network_config_physical_reservoirs(network_dir);
        input_file = cfg.inp_file;
    elseif network == "balerma" && string(anytown_variant) == "r38_anchor"
        cfg = network_config_r38_anchor(network_dir);
        input_file = cfg.inp_file;
    else
        cfg = network_config(network_dir);
        input_file = fullfile(network_dir, 'input', 'network_staci_fixed_load.inp');
    end
    if ~isempty(result_dir_override)
        cfg.results_dir=char(result_dir_override);
    end
    wdn.setup_toolkit(cfg);
    objectives_to_check = string(cfg.objectives);
    if network == "tanyimboh_templeman"
        objectives_to_check(end+1) = "branch_hop_weighted_entropy";
    end
    if network == "anytown" && ismember(string(anytown_variant), ...
            ["physical_reservoirs","anchor_replay"]) && ...
            ~ismember("branch_hop_weighted_entropy", objectives_to_check)
        objectives_to_check = [objectives_to_check, "branch_hop_weighted_entropy"];
    end
    if ~isempty(objective_filter)
        objectives_to_check = string(objective_filter);
    end
    for objective = objectives_to_check
        saved = load(fullfile(cfg.results_dir, objective + ".mat"), 'result');
        result = saved.result;
        assert(strcmp(result.model, 'staci_steady_first_order'), ...
            'Result is not a STACI design');
        if ~isempty(result_dir_override)
            expected_constraint_set='pressure_10_120m_chlorine_mass_split_v2';
            if isfield(cfg,'constraint_set_id')
                expected_constraint_set=cfg.constraint_set_id;
            end
            assert(isfield(result,'constraint_set_id') && ...
                strcmp(result.constraint_set_id,expected_constraint_set), ...
                'Staged design uses another constraint set');
            assert(abs(result.minimum_diameter-cfg.minimum_diameter)<1e-8 && ...
                abs(result.maximum_diameter-cfg.maximum_diameter)<1e-8, ...
                'Staged design uses another diameter range');
        end
        case_dir = fullfile(output_dir, 'cases', char(network), char(objective));
        if ~isfolder(case_dir), mkdir(case_dir); end
        copyfile(input_file, fullfile(case_dir, 'fixed_load.inp'), 'f');
        original_dir = pwd;
        cd(case_dir);
        cd_cleanup = onCleanup(@() cd(original_dir));
        if isfield(cfg, 'epanet_library') && strlength(string(cfg.epanet_library)) > 0
            ep = epanet('fixed_load.inp', cfg.epanet_library);
        else
            ep = epanet('fixed_load.inp');
        end
        ep_cleanup = onCleanup(@() ep.unload());
        st = StaciModel(fullfile(case_dir, 'fixed_load.inp'));
        st_cleanup = onCleanup(@() st.release());
        design_ids = string(cfg.design_link_ids(:));
        x = double(result.design_diameters(:));
        ep_links = string(ep.getLinkNameID);
        [found, design_index] = ismember(design_ids, ep_links);
        assert(all(found) && numel(x) == numel(design_index), 'Design link mismatch');
        diameters = double(ep.getLinkDiameter);
        diameters(design_index) = x;
        ep.setLinkDiameter(diameters);
        if network == "anytown", diameter_scale = 0.0254;
        else, diameter_scale = 0.001;
        end
        st.setLinkProperty(design_ids, 'diameter_m', x * diameter_scale);
        ep.solveCompleteHydraulics;
        ep_head = double(ep.getNodeHydraulicHead); ep_head = ep_head(:);
        ep_pressure = double(ep.getNodePressure); ep_pressure = ep_pressure(:);
        if network == "anytown"
            ep_pressure = ep_pressure * 0.3048 * cfg.pressure_to_head;
        end
        ep_flow = double(ep.getLinkFlows); ep_flow = ep_flow(:);
        ep.solveCompleteQuality;
        ep_chlorine = double(ep.getNodeActualQuality); ep_chlorine = ep_chlorine(:);
        status = st.solveHydraulics();
        assert(status.converged, '%s/%s: STACI did not converge', network, objective);
        sn = st.nodeResults(); sl = st.linkResults();
        sq = st.solveSteadyQuality('chemical');
        ep_nodes = string(ep.getNodeNameID); ep_nodes = ep_nodes(:);
        [found_pressure, pressure_index] = ismember( ...
            string(cfg.pressure_node_ids(:)),ep_nodes);
        assert(all(found_pressure),'Pressure assessment node missing');
        ep_pressure_violation = max([0; ...
            cfg.minimum_pressure - ep_pressure(pressure_index); ...
            ep_pressure(pressure_index) - cfg.maximum_pressure]);
        [found_node, ni] = ismember(ep_nodes, string(sn.id(:)));
        ep_links = ep_links(:);
        [found_link, li] = ismember(ep_links, string(sl.id(:)));
        [found_quality, qi] = ismember(ep_nodes, string(sq.node_ids(:)));
        assert(all(found_node) && all(found_link) && all(found_quality), ...
            '%s/%s: engine ID mismatch', network, objective);
        if network == "anytown"
            head_scale = 0.3048; flow_scale = 6.30901964e-5;
        elseif network == "tanyimboh_templeman"
            head_scale = 1; flow_scale = 1/3600;
        else
            head_scale = 1; flow_scale = 0.001;
        end
        dh = abs(ep_head * head_scale - double(sn.total_head_m(ni)));
        dq = abs(ep_flow * flow_scale - double(sl.flow_rate_m3s(li))) * 1000;
        dc = abs(ep_chlorine - 1000 * double(sq.node_concentration_kgm3(qi)));
        assert(all(isfinite([dh; dq; dc])), 'Non-finite engine difference');
        node_detail=table(ep_nodes,ep_head*head_scale, ...
            double(sn.total_head_m(ni)),dh,ep_chlorine, ...
            1000*double(sq.node_concentration_kgm3(qi)),dc, ...
            'VariableNames',{'NodeID','EPANETHead_m','STACIHead_m', ...
            'AbsoluteHeadDifference_m','EPANETChlorine_mgL', ...
            'STACIChlorine_mgL','AbsoluteChlorineDifference_mgL'});
        writetable(node_detail,fullfile(case_dir,'node_differences.csv'));
        anchor_head_error_ft = NaN;
        anchor_flow_gpm = NaN;
        if network == "anytown" && ~isempty(cfg.pressure_anchor_node_ids)
            [~, ai] = ismember(string(cfg.pressure_anchor_node_ids), ep_nodes);
            [~, fi] = ismember(["78","80"], ep_links);
            anchor_head_error_ft = max(abs(ep_head(ai) - ...
                double(cfg.pressure_anchor_target_heads(:))));
            anchor_flow_gpm = max(abs(ep_flow(fi)));
        elseif network == "balerma" && ...
                string(anytown_variant) == "r38_anchor"
            [found_anchor, ai] = ismember("38",ep_nodes);
            assert(found_anchor,'R38 anchor missing from EPANET validation');
            anchor_head_error_ft = abs(ep_head(ai)/0.3048 - ...
                cfg.pressure_anchor_target_heads);
            % R38 has two connector pipes, which can carry opposite flows.
            % Their individual magnitudes are not the anchor's net supply.
            anchor_flow_gpm = NaN;
        end
        demand_threshold = pi/4 * 0.010^2 * 0.01;
        material = double(sn.demand_m3s(ni)) > demand_threshold;
        min_consumer_chlorine = min(ep_chlorine(material));
        ep_chlorine_violation = max(0,0.2-min_consumer_chlorine);
        row = row + 1;
        rows(row,:) = {network, objective, result.ga_last_generation, ...
            result.exitflag, result.elapsed_time_seconds, numel(dh), numel(dq), ...
            max(dh), mean(dh), max(dq), mean(dq), max(dc), mean(dc), ...
            anchor_head_error_ft, anchor_flow_gpm, min_consumer_chlorine, ...
            result.max_constraint_violation, ep_pressure_violation, ...
            ep_chlorine_violation};
        fprintf('%s/%s: max |dH| %.6g m, |dQ| %.6g L/s, |dCl| %.6g mg/L\n', ...
            network, objective, max(dh), max(dq), max(dc));
        clear st_cleanup ep_cleanup cd_cleanup st ep;
    end
    rmpath(network_dir);
end
comparison = cell2table(rows, 'VariableNames', ...
    {'network','objective','ga_generations','ga_exitflag','ga_wall_seconds', ...
     'node_count','link_count','max_abs_head_m','mean_abs_head_m', ...
     'max_abs_flow_Lps','mean_abs_flow_Lps','max_abs_chlorine_mgL', ...
     'mean_abs_chlorine_mgL','max_anchor_head_deviation_ft', ...
     'max_anchor_connector_flow_GPM','minimum_epanet_consumer_chlorine_mgL', ...
     'staci_max_constraint_violation','epanet_max_pressure_violation', ...
     'epanet_max_chlorine_violation_mgL'});
if network == "balerma" && string(anytown_variant)=="r38_anchor"
    filename='staci_epanet_balerma_r38_anchor_six.csv';
elseif network == "balerma" && ~isempty(result_dir_override)
    filename='staci_epanet_balerma_connected_six.csv';
elseif network == "anytown" && string(anytown_variant)=="anchor_replay"
    filename = 'staci_epanet_anytown_anchor_replay_six.csv';
elseif network == "anytown" && string(anytown_variant)=="physical_reservoirs"
    filename = 'staci_epanet_anytown_physical_six.csv';
elseif numel(networks)==1 && network == "tanyimboh_templeman"
    filename = 'staci_epanet_tanyimboh_six.csv';
elseif isempty(objective_filter)
    filename = 'staci_epanet_current_designs.csv';
else
    filename = 'staci_epanet_selected_designs.csv';
end
writetable(comparison, fullfile(output_dir, filename));
end
