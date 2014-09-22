%-------------------------------------------------------------------------%                 
    function PlateSetups = parse_MultiChannel_WP_format(obj,folder,~,~)
            
            PlateSetups = [];
            %            
            try
                high_dirs = []; 
                z = 0;
                contentdir = dir(obj.Src);
                            for k = 1:numel(contentdir)
                                curelem = char(contentdir(k).name);
                                if ~strcmp(curelem,'.') && ~strcmp(curelem,'..') && isdir([char(obj.Src) filesep curelem])
                                    z = z + 1;
                                    high_dirs{z} = curelem;
                                end
                            end                                
                % ENSURE THAT EVERY HIGH-DIR (MODALITY) CONTAINS LIST OF DIRS (FOVS) WITH THE SAME NAMES
                % FIRST HIGH LEVEL DIRECTORY
                firstdirs = dir([folder filesep char(high_dirs(1))]);
                            z=0;
                            fovdirnames = [];
                            for k = 1:numel(firstdirs)
                                curelem = char(firstdirs(k).name);
                                if ~strcmp(curelem,'.') && ~strcmp(curelem,'..') && isdir([char(obj.Src) filesep char(high_dirs(1)) filesep curelem])
                                    z = z + 1;
                                    fovdirnames{z} = curelem;
                                end
                            end                        
                %
                fovmetadata = extract_metadata(fovdirnames);
                %
                N_high_dirs = numel(high_dirs);            
                for K = 1 : N_high_dirs
                        curhighdirs = dir([folder filesep char(high_dirs(K))]);
                            z=0;
                            curfovdirnames = [];
                            for k = 1:numel(curhighdirs)
                                curelem = char(curhighdirs(k).name);
                                if ~strcmp(curelem,'.') && ~strcmp(curelem,'..') && isdir([char(obj.Src) filesep char(high_dirs(1)) filesep curelem])
                                    z = z + 1;
                                    curfovdirnames{z} = curelem;
                                end
                            end                        
                    %
                    curfovmetadata = extract_metadata(curfovdirnames);
                    if numel(curfovmetadata.Well_FOV) ~= numel(fovmetadata.Well_FOV), errordlg('inconsistent FOV names'), return, end; 
                    for m=1:numel(fovmetadata.Well_FOV)
                        if ~strcmp(char(curfovmetadata.Well_FOV(m)),char(fovmetadata.Well_FOV(m))), errordlg('inconsistent FOV names'), return, end; 
                    end;                                
                end

                PlateSetups.high_dirs = high_dirs;
                PlateSetups.FOV_dirs = fovdirnames;
                PlateSetups.FOV_metadata = fovmetadata;            
                %
                PlateSetups.colMaxNum = 12;
                PlateSetups.rowMaxNum = 8;
                PlateSetups.letters = 'ABCDEFGH';
                PlateSetups.columnNamingConvention = 'number'; % 'Column_Names';
                PlateSetups.rowNamingConvention = 'letter'; %'Row_Names'; 
                PlateSetups.extension = 'tif';
                
                % use fovmetadata to define ros, cols
                PlateSetups.cols = zeros(1,numel(fovdirnames));
                PlateSetups.rows = zeros(1,numel(fovdirnames));
                for k = 1:numel(fovdirnames)
                    PlateSetups.cols(1,k) = fovmetadata.Column{k} - 1;
                    fovlet = char(fovmetadata.Row{k});
                    PlateSetups.rows(1,k) = find(PlateSetups.letters == fovlet) - 1;
                end
                    
            catch err
             display(err.message);    
            end                                                              
    end