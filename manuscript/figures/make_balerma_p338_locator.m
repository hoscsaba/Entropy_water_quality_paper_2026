function output_files=make_balerma_p338_locator(output_dir)
%MAKE_BALERMA_P338_LOCATOR Preserve the P338-specific plotting entry point.
if nargin<1,output_dir=[];end
output_files=make_balerma_pipe_locator("338",output_dir);
end
