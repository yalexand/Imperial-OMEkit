               
folder = [pwd filesep 'TestData' filesep 'Fish 3 - Tumour'];
ometiffilename = [pwd filesep 'TestData' filesep 'Fish 3 - Tumour.OME.tiff'];

if exist(ometiffilename,'file')
    delete(ometiffilename)
end;

addpath_OMEkit;

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
                                      
            acc = zeros(1,num_files);
            for i = 1 : num_files
                I = imread([folder filesep file_names{i}],extension);
                %add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, physszX, physszY);
                %add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, labels);
                %add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step);
                
                telapsed  = add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename);
                acc(i)=telapsed;
            end
            saveBytes_speed = mean(acc)

      
t0 = tic;            
I=zeros(1191, 2559, 'uint16');
imwrite(I, 'dummy','tif');
delete('dummy');

imwrite_speed = toc(t0)
                 
