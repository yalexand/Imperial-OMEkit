               
               
folder = [pwd filesep 'TestData' filesep 'Fish 3 - Tumour'];
ometiffilename = [pwd filesep 'TestData' filesep 'Fish 3 - Tumour.OME.tiff'];

if exist(ometiffilename,'file')
    delete(ometiffilename)
end;

addpath_OMEkit;
            

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
             
labels = (0:1:39); 
Tags_SeparatingSeq = 'jkhsadfgleufyihtiwurehfjkiblaherb';
Tags = ['Raw Fish' Tags_SeparatingSeq 'Fried Fish' Tags_SeparatingSeq 'Gefilte Fish'];
            
            acc = zeros(1,num_files);
            for i = 1 : num_files
                                   
                I = imread([folder filesep file_names{i}],extension);
                
%                telapsed = add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename);
                
                telapsed = add_plane_to_OMEtiff_with_metadata(I, i, num_files, folder, ometiffilename, ...
                    'PhysSz_X', 3.225, ...
                    'PhysSz_Y', 3.225, ...
                    'ModuloZ_Type', 'Rotation', ...
                    'ModuloZ_TypeDescription', 'OPT', ...
                    'ModuloZ_Unit', 'degree', ...
                    'ModuloZ_Start', 0, ...
                    'ModuloZ_Step', 1, ...
                    'ModuloZ_End', 359, ...                        
                    'Tags', Tags, ...            
                    'Tags_SeparatingSeq', Tags_SeparatingSeq);

                acc(i)=telapsed;    
                                               
            end
            saveBytes_speed = mean(acc)
                       