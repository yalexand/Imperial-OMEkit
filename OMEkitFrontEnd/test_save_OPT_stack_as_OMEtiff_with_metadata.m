
folder = [pwd filesep 'TestData' filesep 'Fish 3 - Tumour'];
ometiffilename = [pwd filesep 'TestData' filesep 'Fish 3 - Tumour.OME.tiff'];

if exist(ometiffilename,'file')
    delete(ometiffilename);
end;

addpath_OMEkit;

physszX = 3.225; 
physszY = 3.225;  

zdim_label = 'Rotation';
zdim_unit = 'degree'; 
zdim_typeDescription = 'OPT';

zdim_start = 0;
zdim_end = 359;
zdim_step = 1;

labels = (0:1:359); 

%  save_OPT_stack_as_OMEtiff_with_metadata(folder, ometiffilename, ... 
%      physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step);

speed = save_OPT_stack_as_OMEtiff_with_metadata(folder, ometiffilename)

% speed = save_OPT_stack_as_OMEtiff_with_metadata(folder, ometiffilename, ... 
%      physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, labels);



