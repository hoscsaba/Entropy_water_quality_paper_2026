function make_tanyimboh_epanet_model
%MAKE_TANYIMBOH_EPANET_MODEL Draw the boundary model from the released INP.
% The reference graph has two prescribed inflows. In the EPANET-compatible
% sizing model, node 1 itself is the fixed-head source and node 2 is a fixed negative
% demand. This drawing reads coordinates, links, head and demand from the
% actual INP, so the panel cannot silently drift from the simulation input.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
network_dir=fullfile(root,'networks','tanyimboh_templeman');
inp=fullfile(network_dir,'input','network_staci_fixed_load.inp');
[xy,links,reservoir_head,inlet_demand,demands]=read_model(inp);
assert(abs(reservoir_head-50)<1e-9 && abs(inlet_demand+35)<1e-9, ...
    'TT input boundaries changed; review the schematic labels');

fig=figure('Color','w','Units','centimeters','Position',[2 2 14 12]);
ax=axes(fig, 'Position', [0.02 0.03 0.96 0.94]); hold(ax,'on');
black=[0.12 0.12 0.12]; blue=[0.08 0.35 0.67];
orange=[0.87 0.33 0.10];
for k=1:height(links)
    a=xy(char(links.From(k))); b=xy(char(links.To(k)));
    plot(ax,[a(1) b(1)],[a(2) b(2)],'-', ...
        'Color',black,'LineWidth',2.0);
end

% Identify the eight physical design pipes. Labels
% sit beside their links so the two crossing diagonals remain legible.
pipe_ids=["P1","P4","P7","P6","P2","P3","P8","P5"];
label_xy=[1.33 1.50; -0.23 1.50; -0.23 0.42; 1.33 0.42; ...
          0.84 1.93; 0.24 1.62; 0.55 0.05; 0.55 1.15];
for k=1:numel(pipe_ids)
    link_idx=find(links.ID==pipe_ids(k),1);
    assert(~isempty(link_idx), ...
        'Figure S2(b) pipe ID is absent from the TT input');
    label_rotation=0;
    if ismember(pipe_ids(k),["P2","P3"])
        a=xy(char(links.From(link_idx)));
        b=xy(char(links.To(link_idx)));
        label_rotation=atan2d(b(2)-a(2),b(1)-a(1));
        if label_rotation>90
            label_rotation=label_rotation-180;
        elseif label_rotation<-90
            label_rotation=label_rotation+180;
        end
    end
    text(ax,label_xy(k,1),label_xy(k,2),char(pipe_ids(k)), ...
        'FontName','Times New Roman','FontSize',14, ...
        'Color',black,'HorizontalAlignment','center', ...
        'VerticalAlignment','middle','Rotation',label_rotation, ...
        'BackgroundColor','w', ...
        'Margin',0.5);
end

regular=["3","4","5","6"];
for id=regular
    p=xy(char(id));
    scatter(ax,p(1),p(2),155,'k','filled');
end
p2=xy('2'); r1=xy('1');
scatter(ax,p2(1),p2(2),245,orange,'filled', ...
    'MarkerEdgeColor','k','LineWidth',0.8);
scatter(ax,r1(1),r1(2),245,blue,'s','filled', ...
    'MarkerEdgeColor','k','LineWidth',0.8);

% The orange arrow points vertically into the negative-demand junction.
% The reservoir is directly at node 1; there is no adapter pipe.
quiver(ax,p2(1),p2(2)+0.65,0,-0.50,0, ...
    'Color',orange,'LineWidth',2.3,'MaxHeadSize',1.7);
font='Times New Roman'; sz=18;
text(ax,p2(1),p2(2)+0.82, ...
    sprintf('%g m^3/h',abs(inlet_demand)), ...
    'FontName',font,'FontSize',sz-2,'Color',orange, ...
    'HorizontalAlignment','center','Interpreter','tex');
text(ax,r1(1)+0.30,r1(2)+0.55, ...
    sprintf('R1: H = %g m',reservoir_head), ...
    'FontName',font,'FontSize',sz-2,'Color',blue, ...
    'HorizontalAlignment','center');
% Match the four consumer-withdrawal arrows in the analytical panel. Their
% values are read from the INP rather than transcribed into the drawing.
consumer_ids=["4","3","6","5"];
direction=[-0.62,-0.52];
for id=consumer_ids
    p=xy(char(id));
    start_point=p-0.05*direction;
    arrow_vector=0.70*direction;
    label_point=start_point+arrow_vector+0.24*direction;
    quiver(ax,start_point(1),start_point(2), ...
        arrow_vector(1),arrow_vector(2),0, ...
        'Color',black,'LineWidth',2.0,'MaxHeadSize',1.4);
    text(ax,label_point(1),label_point(2), ...
        sprintf('%g',demands(char(id))), ...
        'FontName',font,'FontSize',sz-2,'Color',black, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
end
ids=["1","2","3","4","5","6"];
offsets=[0.30 -0.18; -0.28 -0.18; 0.27 0.03; ...
    -0.27 0.03; 0.27 -0.02; -0.27 -0.02];
for k=1:numel(ids)
    p=xy(char(ids(k)));
    text(ax,p(1)+offsets(k,1),p(2)+offsets(k,2),char(ids(k)), ...
        'FontName',font,'FontSize',sz,'FontWeight','bold', ...
        'HorizontalAlignment','center','VerticalAlignment','middle');
end
axis(ax,'equal');
xlim(ax,[-0.83 2.20]); ylim(ax,[-0.80 3.20]); axis(ax,'off');
scatter(ax,[-0.83 2.20],[-0.80 3.20],1,'w','filled', ...
    'MarkerEdgeColor','none'); % retain margins in axes-off export

output_dir=fullfile(network_dir,'figures');
if ~isfolder(output_dir),mkdir(output_dir);end
png=fullfile(output_dir,'epanet_boundary_model.png');
svg=fullfile(output_dir,'epanet_boundary_model.svg');
set(fig,'PaperPositionMode','auto');
print(fig,png,'-dpng','-r600');
print(fig,svg,'-dsvg');
close(fig);
generated=fullfile(root,'manuscript','generated','figures');
if ~isfolder(generated),mkdir(generated);end
copyfile(png,fullfile(generated,'tanyimboh_epanet_model.png'),'f');
copyfile(svg,fullfile(generated,'tanyimboh_epanet_model.svg'),'f');
end

function [xy,links,reservoir_head,inlet_demand,demands]=read_model(inp)
lines=readlines(inp); section="";
xy=containers.Map('KeyType','char','ValueType','any');
demands=containers.Map('KeyType','char','ValueType','double');
id=strings(0,1); from=strings(0,1); to=strings(0,1);
reservoir_head=NaN; inlet_demand=NaN;
for k=1:numel(lines)
    no_comment=split(lines(k),';');
    line=strip(no_comment(1));
    if strlength(line)==0,continue;end
    if startsWith(line,'[')
        section=upper(line);continue
    end
    fields=split(line);
    fields=fields(strlength(fields)>0);
    switch section
        case "[COORDINATES]"
            if numel(fields)>=3
                xy(char(fields(1)))=[str2double(fields(2)), ...
                    str2double(fields(3))];
            end
        case "[PIPES]"
            if numel(fields)>=3
                id(end+1,1)=fields(1); %#ok<AGROW>
                from(end+1,1)=fields(2); %#ok<AGROW>
                to(end+1,1)=fields(3); %#ok<AGROW>
            end
        case "[RESERVOIRS]"
            if numel(fields)>=2 && fields(1)=="1"
                reservoir_head=str2double(fields(2));
            end
        case "[DEMANDS]"
            if numel(fields)>=2
                demands(char(fields(1)))=str2double(fields(2));
                if fields(1)=="2"
                    inlet_demand=str2double(fields(2));
                end
            end
    end
end
links=table(id,from,to,'VariableNames',{'ID','From','To'});
assert(all(isfinite([reservoir_head,inlet_demand])) && ...
    all(ismember(["1","2","3","4","5","6"],keys(xy))) && ...
    all(ismember(["3","4","5","6"],keys(demands))) && ...
    numel(unique(links.ID))==8 && ~any(links.ID=="P_input_2"), ...
    'Incomplete TT EPANET boundary input');
end
