function project_v9p2

% Settings

output_file = 'wolf_code_opt_cost_250729.txt';
network_inp_file = 'wolf-initial-fig.inp';

d = epanet(network_inp_file);

% Pipe diameters
LB = 1; % Lower bound
UB = 1000; % Upper bound

num_iterations = 100;  % Number of times to run the genetic algorithm

local_opt = true;

num_of_links = double(d.getLinkCount);
options = optimoptions('ga', ...
    'Display', 'iter', ...
    'PopulationSize', 200, ...
    'MaxGenerations', 100, ...
    'MaxStallGenerations', 20, ...
    'UseParallel', true);  % can be true if you want parallel eval

%opts = optimset('Display','iter','PlotFcns',@optimplotfval);

local_options = optimset( 'Display', 'iter', ...   
    'MaxIter', 1e3, ...                    
    'TolCon', 1e-5);           

    %'FunctionTolerance', 1e-5, ...  
    %'MaxFunctionEvaluations', 1e5, ...

% Initial setup

units = d.getUnits;
US = units.Units_US_Customary;

LowB = LB * ones(1,d.getLinkCount);
UppB = UB * ones(1,d.getLinkCount);

fitnessFcn = @(x) cost_f(x, d);
nonlcon = @(x) constrains(x, d, US);

% Open file for appending
fileID = fopen(output_file, 'a');


% GA loop
for iter = 1:num_iterations

    % Run genetic algorithm
    [x_opt,~] = ga(fitnessFcn, num_of_links, [], [], [], [], LowB, UppB, [], options);

    if (local_opt)
        [x_opt, ~] = patternsearch(fitnessFcn, x_opt, ...
        [], [], [], [], LowB, UppB, [], local_options);
    end

    % Recalculate entropy and cost using refined solution
    S = entropy(x_opt,d);
    C = cost_f(x_opt,d);
    
    
    d.setLinkDiameter(x_opt);
    d.solveCompleteHydraulics;
    Flow_Rates = d.getLinkFlows;
    Pressures = d.getNodePressure;
    Velocities = d.getLinkVelocity;
    HeadLoss = d.getLinkHeadloss;

    % Write results to file
    fprintf(fileID, 'Optimal Diameters: ');
    fprintf(fileID, '%6.2f ', x_opt);
    fprintf(fileID, ' Entropy: %6.6f ', S);
    fprintf(fileID, ' Cost: %6.6f ', C);
    fprintf(fileID, 'Flow Rates:');
    fprintf(fileID, '%6.6f ', Flow_Rates);
    fprintf(fileID, 'Pressures:');
    fprintf(fileID, '%6.6f ', Pressures);
    fprintf(fileID, 'HeadLoss:');
    fprintf(fileID, '%6.6f ', HeadLoss);
    fprintf(fileID, 'Velocities:');
    fprintf(fileID, '%6.6f ', Velocities);
    fprintf(fileID, '\n');

    % Visulialize results and progress
    disp("Number of iteration:");
    disp(iter);

end

fclose(fileID); % Close the file

end

function [c,c_eq] = constrains(x,d,US)

    if (US)
        P_min = 33;
        P_max = 165;
    else
        P_min = 10;
        P_max = 50;
    end

    d.setLinkDiameter(x);
    d.solveCompleteHydraulics;
    Junctions = d.getNodeJunctionIndex;
    Num_Nodes = d.getNodeCount;
    pen = 0;
    P = d.getNodePressure;
    %for i = 1:Num_Nodes
    %    if ismember(i, Junctions)
    %        if (P(i) < P_min) % 33 ft = 10 m = 1 bar
    %            pen = pen + abs(P(i)-P_min);
    %        else
    %            if (P(i) > P_max) % 165 ft = 50 m = 5 bar
    %                pen = pen + abs(P(i)-P_max);
    %            end
    %        end
    %    end
    %end
    d.setLinkDiameter(x);
    d.solveCompleteHydraulics;
    Junctions = d.getNodeJunctionIndex;
    P = d.getNodePressure;
    
    % Collect inequalities for all junctions
    P_junct = P(Junctions); % Only at junctions

    c1 = P_min - P_junct;   % Should be <= 0  (P_junct >= 33)
    c2 = P_junct - P_max;  % Should be <= 0  (P_junct <= 165)
    
    c = [c1; c2];
    %c_eq = pen;
    c_eq = [];
end

%function co = cost(d,len)
%
%    co = 2.385 * 0.00001 * power(d,5.742) * len;
%end


function co = cost(dia,len)

    d = dia;
    %d = (dia*0.1)/2.54;
    co = (-0.611924 * d + 2.39987 * power(d,2) - 0.593326 * power(d,3) + 0.0645 * power(d,4) - 0.00309 * power(d,5) + 0.0000556 * power(d,6)) * len; % 185000
    if (co < 0)
        co = 0;
    end
    %c0 = power(diameter,1.4) / 368;

end

function S = entropy(x,d)

    d.setLinkDiameter(x);
    d.solveCompleteHydraulics;

    % Datas from EPANET
    Flow_Rates = d.getLinkFlows; 
    Demands = d.getNodeBaseDemands;
    Demands = cell2mat(Demands);
    Num_Nodes = d.getNodeCount;
    Num_Links = d.getLinkCount;
    Num_Junctions = d.getNodeJunctionCount;
    Links = d.getLinkNodesIndex;
    Flow_Magnitudes = abs(Flow_Rates);
    Flow_Directions = sign(Flow_Rates);
    Junctions = d.getNodeJunctionIndex;

    %[HeadLoss]


    % Links correction based on flow directions
    for i = 1:Num_Links
        if Flow_Directions(i) < 0
            Links(i, :) = flip(Links(i, :));
        end
    end

% FOR ALL NODES

    % Check Input and Output properties
    Nodes = unique(Links(:));
    Out_degree = histcounts(Links(:,1), [Nodes; max(Nodes) + 1]);
    In_degree = histcounts(Links(:,2), [Nodes; max(Nodes) + 1]);

    % Creating all necessary probability arrays
    p_Nodes = zeros(1,Num_Nodes); % Here I save the probability of Demands Links
    p_Weight = zeros(1,Num_Nodes); % Here I save the actual flow probabilities for the Nodes
    p_Links = zeros(1, Num_Links);
    Ss = zeros(1, Num_Nodes + 1);

    % Get all necessary preliminary node for every node
    for i = 1:Num_Nodes
    Node = Nodes(i);
    Input_Nodes{i} = Links(Links(:,2) == Node, 1);
    Output_Nodes{i} = Links(Links(:,1) == Node, 2);
    end

% Get TOTAL Input flow value
    Total_In = 0;
    Num_Inputs = 0;
    Inputs = [];
    for i = 1:Num_Nodes
        if (In_degree(i) == 0)
            Num_Inputs = Num_Inputs + 1;
            Inputs = [ Inputs , i ];
            Input_Flows = Flow_Magnitudes(Links(:,1) == i);
            for j = 1:Out_degree(i)
                Total_In = Total_In + Input_Flows(j);
            end
            if (Demands < 0)
                Total_In = Total_In + Demands(i);
            end
        end
    end

% Calculate Input Node probabilities
    Total_In_N = 0;
    for i = 1:Num_Inputs
        Total_In_N = 0;
        if (In_degree(Inputs(i)) == 0)
            Input_Flows = Flow_Magnitudes(Links(:,1) == Inputs(i));
            p_Links(Links(:,1) == Inputs(i)) = 1;
            for j = 1:Out_degree(Inputs(i))
                Total_In_N = Total_In_N + Input_Flows(j);
            end
            if (Demands < 0)
                Total_In_N = Total_In_N - Demands(Inputs(i));
            end
            p_Nodes(Inputs(i)) = Total_In_N / Total_In;
            p_Weight(Inputs(i)) = Total_In_N / Total_In;
        end
    end

% PREPROCESS JUNCTIONS

    Processable_Junctions = find(In_degree == 0);
    Processable_Junctions = Processable_Junctions(ismember(Processable_Junctions, Junctions));
    if (isempty(Processable_Junctions))
        for i = 1:Num_Junctions
            Processable = true;
            for j = 1:In_degree(i)
                if (ismember(Input_Nodes{i}(j),Junctions))
                    Processable = false;
                end
            end
            if (Processable)
                Processable_Junctions = [ Processable_Junctions, i ]; % Saving the index
            end
        end
    end

    Processed_Junctions = [];

% PROCESS JUNCTIONS
    % Data processing loop
    while ~isempty(Processable_Junctions)

        Current_Junction = Processable_Junctions(1);
        Processable_Junctions(1) = [];

        % Node probabilities
        Total_Outflow = 0;
        for i = 1:Num_Links
            if (Links(i,1) == Current_Junction)
                Total_Outflow = Total_Outflow + Flow_Magnitudes(i);
            end
        end
        if (Demands(Current_Junction) > 0)
            p_Nodes(Current_Junction) = Demands(Current_Junction) / (Total_Outflow + Demands(Current_Junction));
        else
            p_Nodes(Current_Junction) = 0;
        end
       
        % Link probabilities -> All output of the nodes
        for i = 1:Num_Links
            if (Links(i,1) == Current_Junction)
                if (Demands(Current_Junction) > 0)
                    p_Links(i) = Flow_Magnitudes(i) / (Total_Outflow + Demands(Current_Junction));
                else
                    p_Links(i) = Flow_Magnitudes(i) / (Total_Outflow);
                end
            end
        end

        % Calculate Entropy for the nodes
        s_temp = 0;
        Link_index = find(Links(:,1) == Current_Junction);
        for i = 1:Out_degree(Current_Junction)
            s_temp = s_temp + p_Links(Link_index(i)) * log2(p_Links(Link_index(i)));
        end
        if (Demands(Current_Junction) > 0)
            s_temp = s_temp + p_Nodes(Current_Junction) * log2(p_Nodes(Current_Junction));
        end
        

        % Input probabilities for each Node
        for i = 1:In_degree(Current_Junction)
            Link_index2 = Links(:,2) == Current_Junction & Links(:,1) == Input_Nodes{Current_Junction}(i);
            p_Weight(Current_Junction) = p_Weight(Current_Junction) + p_Weight(Input_Nodes{Current_Junction}(i)) * p_Links(Link_index2); %P_Nodes input node eseten, hanem p_Weight
        end

        Ss(Current_Junction) = - p_Weight(Current_Junction) * s_temp;


        % Add to processed nodes
        Processed_Junctions = [ Processed_Junctions, Current_Junction ];

        % Add new processable nodes
        for i = 1:Num_Junctions
            Processable = true;
            for j = 1:length(Input_Nodes{i})
                if ((ismember(Input_Nodes{i}(j), Junctions)) && (~ismember(Input_Nodes{i}(j), Processed_Junctions)))
                    Processable = false;
                    break;
                end
            end
            if (Processable && ~ismember(Junctions(i), Processable_Junctions) && ~ismember(Junctions(i), Processed_Junctions))
                Processable_Junctions = [ Processable_Junctions, Junctions(i) ];
            end
        end
    end


    % Calculate S0
    Ss(length(Nodes) + 1) = 0;
    for i = 1:Num_Nodes
        if (In_degree(i) == 0)
            if p_Weight(i) > 0
                Ss(Num_Nodes + 1) = Ss(Num_Nodes + 1) - p_Weight(i) * log2(p_Weight(i));
            end
        end
    end

    S = - sum(Ss);

end

function C = cost_f(x,d)

    % Data from EPANET
    Num_Links = d.getLinkCount;
    Lengths = d.getLinkLength;

    Cs = zeros(1, Num_Links);
    for i = 1:Num_Links
        Cs(i) = cost(x(i), Lengths(i));
    end

    C = sum(Cs);

end