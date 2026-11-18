function make_portrait_submission_figures()
%MAKE_PORTRAIT_SUBMISSION_FIGURES Reflow only the panels used by current SM.
% The source composites and editable SVGs remain alongside these PNG crops.
% This visual operation does not solve hydraulics or change numerical data.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder=fullfile(root,'manuscript','generated','figures');
assert(isfolder(folder),'Run reproduce_all_figures first.');
wide_pair(folder,'chlorine_entropy_loop_pair');
panel_pairs(folder,'figure5');
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
starts=round([0 .32 .64]*W);
ends=round([.31 .62 .935]*W);
% The previous 93.5%% cut also captured R10 and the adjacent pump label
% from the third network panel; the color scale itself starts past 95%%.
bar=I(:,round(.951*W)+1:end,:);
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
% These portrait crops are raster page layouts; the uncropped source SVG
% beside each source PNG is the editable vector artwork. Exporting a MATLAB
% image object as SVG produces an empty page on some graphics backends.
imwrite(I,[base '.png']);
end
