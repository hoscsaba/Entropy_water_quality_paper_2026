function output_files = make_balerma_pipe_only_figures(output_dir,result_dir)
%MAKE_BALERMA_PIPE_ONLY_FIGURES Plot the six saved Balerma diameter designs.
%   Pipe diameter controls both color and line width. Nodes and reservoir
%   markers are omitted. The six panels follow the pressure/chlorine map
%   order in the Supplementary Material and share one logarithmic color
%   scale from 8 to 64 in. Pipes at or below 8 in use the same blue; their
%   actual diameters still determine width and the <=1-in dashed style. This
%   function reads the original INP and the full-precision
%   diameter CSV; it does not run hydraulics, quality, or optimization.
%
%   The optional result_dir selects a versioned six-design diameter CSV.
%   The plot writes PNG and editable SVG files to output_dir.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir = fullfile(root,'networks','balerma');
if nargin < 1 || isempty(output_dir)
    output_dir = fullfile(network_dir, ...
        'figures_staci_r38_anchor_v1');
end
if ~isfolder(output_dir), mkdir(output_dir); end
inp_file = fullfile(network_dir,'input','network_original.inp');
publish = nargin < 2 || isempty(result_dir);
if publish
    result_dir = fullfile(network_dir, ...
        'results_staci_r38_anchor_r44_physical_0p1_64in_v1');
end
csv_file = fullfile(result_dir,'optimal_pipe_diameters_six_in.csv');
[pipe_id,from_id,to_id,node_id,node_x,node_y] = read_inp_map(inp_file);
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
if ismember('Cost_in',T.Properties.VariableNames)
    column_names = {'Cost_in','FlowEntropy_in','BranchHopEntropy_in', ...
        'ChlorineConcentration_in','ChlorineEntropy_in','Todini_in'};
else
    column_names = {'cost','hydraulic_entropy', ...
        'branch_hop_weighted_entropy','chlorine_concentration', ...
        'chlorine_entropy','todini'};
end
titles = {'(a) Cost','(b) Flow entropy','(c) Branch-hop entropy', ...
    '(d) Chlorine concentration','(e) Chlorine entropy','(f) Todini index'};
D = table2array(T(row,column_names));
assert(all(isfinite(D(:))) && all(D(:)>=0.1-1e-6) && ...
    all(D(:)<=64+1e-6),'Saved diameter is outside the common 0.1--64 in range.');
span_x = max(node_x)-min(node_x);
span_y = max(node_y)-min(node_y);
x_limits = [min(node_x)-0.025*span_x,max(node_x)+0.025*span_x];
y_limits = [min(node_y)-0.025*span_y,max(node_y)+0.025*span_y];
color_limits = log10([8 64]);
% Start the continuous Turbo scale in its blue range rather than purple.
full_cmap = turbo(320);
cmap = full_cmap(52:307,:);

fig = figure('Color','w','Units','centimeters','Position',[2 2 18 22]);
layout = tiledlayout(fig,3,2,'TileSpacing','compact','Padding','compact');
colormap(fig,cmap);
for panel = 1:6
    ax = nexttile(layout);
    hold(ax,'on');
    for k = 1:454
        diameter = D(k,panel);
        % Sqrt scaling keeps small pipes visible while distinguishing
        % large pipes without obscuring neighboring links.
        line_width = 0.35 + 2.8*sqrt(diameter/64);
        u = (log10(max(diameter,8))-color_limits(1))/diff(color_limits);
        ci = max(1,min(256,1+round(255*u)));
        line_style = '-';
        if diameter<=1, line_style='--'; end
        plot(ax,node_x([from_ix(k),to_ix(k)]), ...
            node_y([from_ix(k),to_ix(k)]), ...
            'Color',cmap(ci,:),'LineWidth',line_width, ...
            'LineStyle',line_style);
    end
    axis(ax,'equal'); axis(ax,'off');
    xlim(ax,x_limits); ylim(ax,y_limits); clim(ax,color_limits);
    title(ax,titles{panel},'FontSize',11,'FontWeight','normal');
end
cb = colorbar(ax);
cb.Layout.Tile = 'east';
cb.FontSize = 11;
cb.Ticks = log10([8 16 32 64]);
cb.TickLabels = {'8','16','32','64'};
ylabel(cb,'Pipe diameter [in]','FontSize',11);

basename = 'balerma_common_pipe_diameters_only';
if contains(string(result_dir),'r38_anchor')
    basename='balerma_r38_anchor_pipe_diameters_only';
end
output_files = {fullfile(output_dir,[basename '.png']), ...
    fullfile(output_dir,[basename '.svg'])};
exportgraphics(fig,output_files{1},'Resolution',350);
exportgraphics(fig,output_files{2},'ContentType','vector');
close(fig);

% The versioned manuscript assets are copied from the same rendering.
if publish
    generated_dir = fullfile(root,'manuscript','generated','figures');
    if ~isfolder(generated_dir), mkdir(generated_dir); end
    copyfile(output_files{1},fullfile(generated_dir,[basename '.png']),'f');
    copyfile(output_files{2},fullfile(generated_dir,[basename '.svg']),'f');
end
end

function [pipe_id,from_id,to_id,node_id,node_x,node_y] = read_inp_map(inp_file)
% Read only INP geometry; no EPANET or STACI call is made.
lines = readlines(inp_file);
section = "";
pipe_id = strings(0,1); from_id = strings(0,1);
to_id = strings(0,1);
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
    if section=="PIPES" && numel(parts)>=3
        id = string(parts{1});
        if ~startsWith(id,"P"), id="P"+id; end
        pipe_id(end+1,1) = id; %#ok<AGROW>
        from_id(end+1,1) = string(parts{2}); %#ok<AGROW>
        to_id(end+1,1) = string(parts{3}); %#ok<AGROW>
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
