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
for k=1:3
    a=I(1:split,starts(k)+1:ends(k),:);
    b=I(split+1:end,starts(k)+1:ends(k),:);
    w=max(size(a,2),size(b,2));
    canvas=uint8(255*ones(H,w+size(bar,2),3));
    canvas(1:size(a,1),1:size(a,2),:)=a;
    canvas(split+1:split+size(b,1),1:size(b,2),:)=b;
    canvas(:,w+1:end,:)=bar;
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
