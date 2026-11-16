function output_files = make_balerma_pipe_only_figures(output_dir)
%MAKE_BALERMA_PIPE_ONLY_FIGURES Plot six saved Balerma diameter designs.
%   Reads the original INP coordinates, pipe lengths, and the full-precision
%   diameter CSV. It performs no hydraulic, chlorine, or optimization solve.
%   Each figure has the same 3-by-2 design order as Supplementary Figures
%   S18 and S19. Nodes and reservoir markers are deliberately omitted.
%
%   Figure 1: pipe diameter controls both color and line width.
%   Figure 2: fixed physical pipe length controls color; saved diameter
%   controls line width, so the two different properties remain visible.
%
%   make_balerma_pipe_only_figures() writes PNG and editable SVG files to
%   networks/balerma/figures_staci_uniform_0p1_64in_staging.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir = fullfile(root,'networks','balerma');
if nargin < 1 || isempty(output_dir)
    output_dir = fullfile(network_dir, ...
        'figures_staci_uniform_0p1_64in_staging');
end
if ~isfolder(output_dir), mkdir(output_dir); end
inp_file = fullfile(network_dir,'input','network_original.inp');
csv_file = fullfile(network_dir, ...
    'results_staci_uniform_0p1_64in_staging', ...
    'optimal_pipe_diameters_six_in.csv');
[pipe_id,from_id,to_id,pipe_length,node_id,node_x,node_y] = read_inp_map(inp_file);
T = readtable(csv_file,'TextType','string');
assert(height(T)==454 && numel(pipe_id)==454, ...
    'Expected 454 physical Balerma pipes in the INP and diameter CSV.');
[found,row] = ismember(pipe_id,string(T.PipeID));
assert(all(found) && numel(unique(row))==454, ...
    'Diameter CSV pipe IDs do not match the original INP pipes.');
[found_from,from_ix] = ismember(from_id,node_id);
[found_to,to_ix] = ismember(to_id,node_id);
assert(all(found_from & found_to), ...
    'Some pipe endpoints have no INP coordinates.');
column_names = {'Cost_in','FlowEntropy_in','BranchHopEntropy_in', ...
    'ChlorineConcentration_in','ChlorineEntropy_in','Todini_in'};
titles = {'(a) Cost','(b) Flow entropy','(c) Branch-hop entropy', ...
    '(d) Chlorine concentration','(e) Chlorine entropy','(f) Todini index'};
D = table2array(T(row,column_names));
assert(all(isfinite(D(:))) && all(D(:)>=0.1-1e-6) && ...
    all(D(:)<=64+1e-6),'Saved diameter is outside the common 0.1--64 in range.');
assert(all(isfinite(pipe_length)) && all(pipe_length>0), ...
    'INP pipe lengths must be positive and finite.');
span_x = max(node_x)-min(node_x);
span_y = max(node_y)-min(node_y);
x_limits = [min(node_x)-0.025*span_x,max(node_x)+0.025*span_x];
y_limits = [min(node_y)-0.025*span_y,max(node_y)+0.025*span_y];
length_limits = [min(pipe_length),max(pipe_length)];

output_files = cell(2,2);
for mode = 1:2
    fig = figure('Color','w','Units','centimeters', ...
        'Position',[2 2 18 22]);
    layout = tiledlayout(fig,3,2,'TileSpacing','compact', ...
        'Padding','compact');
    if mode==1
        cmap = turbo(256);
        color_limits = log10([0.1 64]);
        basename = 'balerma_common_pipe_diameters_only';
    else
        cmap = parula(256);
        color_limits = log10(length_limits);
        basename = 'balerma_common_pipe_lengths_only';
    end
    colormap(fig,cmap);
    for panel = 1:6
        ax = nexttile(layout);
        hold(ax,'on');
        for k = 1:454
            diameter = D(k,panel);
            % Sqrt scaling keeps small pipes visible while separating the
            % thick trunk pipes without allowing them to obscure neighbours.
            line_width = 0.35 + 2.8*sqrt(diameter/64);
            if mode==1
                color_value = log10(diameter);
            else
                color_value = log10(pipe_length(k));
            end
            u = (color_value-color_limits(1))/diff(color_limits);
            ci = max(1,min(256,1+round(255*u)));
            line_style = '-';
            if diameter<=1, line_style='--'; end
            plot(ax,node_x([from_ix(k),to_ix(k)]), ...
                node_y([from_ix(k),to_ix(k)]), ...
                'Color',cmap(ci,:),'LineWidth',line_width, ...
                'LineStyle',line_style);
        end
        axis(ax,'equal'); axis(ax,'off');
        xlim(ax,x_limits); ylim(ax,y_limits);
        clim(ax,color_limits);
        title(ax,titles{panel},'FontSize',12.5,'FontWeight','normal');
    end
    cb = colorbar(ax);
    cb.Layout.Tile = 'east';
    cb.FontSize = 11;
    if mode==1
        cb.Ticks = log10([0.1 1 4 16 64]);
        cb.TickLabels = {'0.1','1','4','16','64'};
        ylabel(cb,'Pipe diameter [in]','FontSize',11);
    else
        cb.Ticks = log10([25 100 250 500 2500]);
        cb.TickLabels = {'25','100','250','500','2500'};
        ylabel(cb,'Physical pipe length [m]','FontSize',11);
    end
    output_files{mode,1} = fullfile(output_dir,[basename '.png']);
    output_files{mode,2} = fullfile(output_dir,[basename '.svg']);
    exportgraphics(fig,output_files{mode,1},'Resolution',350);
    exportgraphics(fig,output_files{mode,2},'ContentType','vector');
    close(fig);
end
end

function [pipe_id,from_id,to_id,pipe_length,node_id,node_x,node_y] = read_inp_map(inp_file)
% Read only the geometry needed for plotting; no EPANET call is made.
lines = readlines(inp_file);
section = "";
pipe_id = strings(0,1); from_id = strings(0,1);
to_id = strings(0,1); pipe_length = zeros(0,1);
node_id = strings(0,1); node_x = zeros(0,1); node_y = zeros(0,1);
for j = 1:numel(lines)
    line = regexprep(char(lines(j)),';.*$','');
    line = strtrim(line);
    if isempty(line), continue; end
    if line(1)=='['
        section = upper(string(regexprep(line,'[\[\]]','')));
        continue;
    end
    parts = regexp(line,'\s+','split');
    if section=="PIPES" && numel(parts)>=4
        id = string(parts{1});
        if ~startsWith(id,"P"), id="P"+id; end
        pipe_id(end+1,1) = id; %#ok<AGROW>
        from_id(end+1,1) = string(parts{2}); %#ok<AGROW>
        to_id(end+1,1) = string(parts{3}); %#ok<AGROW>
        pipe_length(end+1,1) = str2double(parts{4}); %#ok<AGROW>
    elseif section=="COORDINATES" && numel(parts)>=3
        node_id(end+1,1) = string(parts{1}); %#ok<AGROW>
        node_x(end+1,1) = str2double(parts{2}); %#ok<AGROW>
        node_y(end+1,1) = str2double(parts{3}); %#ok<AGROW>
    end
end
assert(numel(unique(pipe_id))==numel(pipe_id), ...
    'Duplicate physical pipe IDs in original INP.');
assert(numel(unique(node_id))==numel(node_id), ...
    'Duplicate node coordinates in original INP.');
end
