folder = 'C:\Users\yalexand\omero_YA\OPT_examples\fluor';
ometiffilename = 'C:\Users\yalexand\omero_YA\fluor.ome.tiff';
               
%             extension  = 'tif';
%             
%             files = dir([folder filesep '*.' extension]);
%             num_files = length(files);
%             if 0 ~= num_files
%                 file_names = cell(1,num_files);
%                 for k = 1:num_files
%                     file_names{k} = char(files(k).name);
%                 end
%             else
%                 return, 
%             end;               
% 
%             if isempty(file_names) || 0 == numel(file_names), return, end;
%             
%             num_files = numel(file_names);
%             
%             for i = 1 : num_files
%                 I = imread([folder filesep file_names{i}],extension);
%                 add_plane_to_OMEtiff(I, i, num_files, folder, ometiffilename);
%             end

            
physszX = 3.225; 
physszY = 3.225;  
zdim_label = 'Rotation';
zdim_unit = 'degree'; 
zdim_typeDescription = 'OPT';
zdim_start = 0;
zdim_end = 359;
zdim_step = 1;

% labels = (0:1:359); 
labels = (0:1:39); 

            extension  = 'tif';
            
            files = dir([folder filesep '*.' extension]);
            num_files = length(files);
            if 0 ~= num_files
                file_names = cell(1,num_files);
                for k = 1:num_files
                    file_names{k} = char(files(k).name);
                end
            else
                return, 
            end;               

            if isempty(file_names) || 0 == numel(file_names), return, end;
            
            %num_files = numel(file_names);
                                    
            for i = 1 : num_files
                I = imread([folder filesep file_names{i}],extension);
                %add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, physszX, physszY);
                %add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, labels);
                add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step);                 
                %add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename);                 
            end
                       
% C:\Users\yalexand\omero_YA\OPT_examples\fluor
% C:\Users\yalexand\omero_YA\fluor.ome.tiff
% C:\Users\yalexand\omero_YA\OPT_examples\fluor\AK5 - REPEAT - GREEN TEST - acquisition metadata.xml

% test_add_plane_to_OMEtiff('C:\Users\yalexand\omero_YA\OPT_examples\fluor','C:\Users\yalexand\omero_YA\fluor.ome.tiff');

