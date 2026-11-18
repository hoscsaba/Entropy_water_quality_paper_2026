function output_file=write_balerma_r38_anchor_input(input_file,output_file)
%WRITE_BALERMA_R38_ANCHOR_INPUT Replace only R38 by a zero-demand junction.
% R43, R44 and R88 retain their original fixed heads and chlorine sources.
% The two R38 connector pipes are unchanged. The prescribed 117 m total
% head is imposed by the optimizer, not by this hydraulic input.
assert(~strcmp(char(input_file),char(output_file)), ...
    'The physical-reservoir input must remain unchanged');
lines=regexp(fileread(input_file),'\r\n|\n|\r','split');
section="";
out=strings(0,1);
found=struct('reservoir',false,'quality',false,'source',false, ...
    'junction',false);
for k=1:numel(lines)
    line=string(lines{k});
    data=strip(regexprep(line,';.*$',''));
    if startsWith(data,'[')
        section=upper(data);
        out(end+1,1)=line; %#ok<AGROW>
        if section=="[JUNCTIONS]"
            out(end+1,1)=" 38 117.000000 0.000000"; %#ok<AGROW>
            found.junction=true;
        end
        continue
    end
    token=split(data);
    token(token=="")=[];
    if ~isempty(token) && token(1)=="38"
        switch section
            case "[RESERVOIRS]"
                assert(numel(token)>=2 && abs(str2double(token(2))-117)<1e-9, ...
                    'The original R38 total head changed');
                found.reservoir=true;
                continue
            case "[QUALITY]"
                found.quality=true;
                continue
            case "[SOURCES]"
                assert(numel(token)>=3 && strcmpi(token(2),'CONCEN'), ...
                    'Unexpected R38 chlorine boundary');
                found.source=true;
                continue
        end
    end
    out(end+1,1)=line; %#ok<AGROW>
end
assert(all(structfun(@(v)v,found)), ...
    'The expected R38 reservoir and quality records were not found');
text=join(out,newline);
assert(contains(text," 44") && contains(text," 43") && ...
    contains(text," 88"), 'Physical Balerma sources were lost');
if ~isfolder(fileparts(output_file)),mkdir(fileparts(output_file));end
expected=sprintf('%s\n',text);
if isfile(output_file) && strcmp(fileread(output_file),expected)
    return
end
fid=fopen(output_file,'w');
assert(fid>0,'Cannot write R38-anchor nominal input');
release=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',expected);
end
