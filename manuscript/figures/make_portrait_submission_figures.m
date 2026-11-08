function make_portrait_submission_figures()
%MAKE_PORTRAIT_SUBMISSION_FIGURES Reflow saved art for portrait pages.
% Visual reformatting only: no hydraulic, chlorine or optimization runs.
% The original full-resolution composites remain the numerical source.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=fullfile(root,'manuscript','generated','figures');
assert(isfolder(folder),'Run reproduce_all_figures first.');
wide_pair(folder,'entropy_loop_two_consumers');
wide_pair(folder,'chlorine_entropy_loop_pair');
wide_pair(folder,'tanyimboh_equal_entropy_pair');
node6=fullfile(root,'networks','tanyimboh_templeman', ...
    'experiments','node6_reservoir','node6_reservoir_equal_entropy_pair.png');
copyfile(node6,fullfile(folder,'node6_reservoir_equal_entropy_pair.png'),'f');
wide_pair(folder,'node6_reservoir_equal_entropy_pair');
names={'figure3','figure4','figure5','figure10_balerma_objectives', ...
    'figure14_balerma_chlorine'};
for i=1:numel(names)
    panel_pairs(folder,names{i});
end
% Two overlapping views keep the original link and node identifiers legible.
I=imread(fullfile(folder,'anytown_schematic.png')); W=size(I,2);
imwrite(I(:,1:round(.59*W),:), ...
    fullfile(folder,'anytown_schematic_west.png'));
imwrite(I(:,round(.41*W):end,:), ...
    fullfile(folder,'anytown_schematic_east.png'));
fprintf('Portrait art written to %s\n',folder);
end

function wide_pair(folder,base)
I=imread(fullfile(folder,[base '.png']));
W=size(I,2); mid=round(W/2); H=size(I,1);
A=I(:,1:mid,:); B=I(:,mid+1:end,:);
width=max(size(A,2),size(B,2));
canvas=uint8(255*ones(2*H+round(.025*H),width,3));
canvas(1:H,1:size(A,2),:)=A;
y0=H+round(.025*H)+1;
canvas(y0:y0+H-1,1:size(B,2),:)=B;
save_art(canvas,fullfile(folder,[base '_portrait']));
end

function panel_pairs(folder,base)
I=imread(fullfile(folder,[base '.png']));
W=size(I,2); H=size(I,1); split=round(H/2);
% Original six-panel source uses three equal columns plus a shared colorbar.
xs=round([0 .32 .64 .935]*W);
starts=round([0 .32 .64]*W);
ends=round([.31 .62 .935]*W);
bar=I(:,xs(4)+1:end,:);
% Pair cost with chlorine concentration; compare both hydraulic entropy
% variants in the next figure; then show chlorine entropy beside Todini.
pairs=[1 4;2 3;5 6];
for k=1:3
    tiles=cell(1,2);
    for row=1:2
        idx=pairs(k,row);
        panel_row=ceil(idx/3);
        panel_col=mod(idx-1,3)+1;
        if panel_row==1, yrange=1:split;
        else, yrange=split+1:H; end
        tiles{row}=I(yrange,starts(panel_col)+1:ends(panel_col),:);
    end
    a=tiles{1};b=tiles{2};
    h1=size(a,1);h2=size(b,1);
    w=max(size(a,2),size(b,2));
    canvas=uint8(255*ones(h1+h2,w+size(bar,2),3));
    canvas(1:h1,1:size(a,2),:)=a;
    canvas(h1+1:h1+h2,1:size(b,2),:)=b;
    bar_view=bar(1:min(size(bar,1),h1+h2),:,:);
    canvas(1:size(bar_view,1),w+1:end,:)=bar_view;
    if size(bar_view,1)<h1+h2
        canvas(end,w+1:end,:)=bar_view(end,:,:);
    end
    save_art(canvas,fullfile(folder,sprintf('%s_portrait_%d',base,k)));
end
end

function save_art(I,base)
imwrite(I,[base '.png']);
fig=figure('Visible','off','Color','w','Units','pixels', ...
    'Position',[100 100 size(I,2) size(I,1)]);
ax=axes(fig,'Position',[0 0 1 1]); image(ax,I); axis(ax,'image'); axis(ax,'off');
exportgraphics(fig,[base '.svg'],'ContentType','image');
close(fig);
end
