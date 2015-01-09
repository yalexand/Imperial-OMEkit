
classdef ic_OPTtools_data_controller < handle 
    
    % Copyright (C) 2013 Imperial College London.
    % All rights reserved.
    %
    % This program is free software; you can redistribute it and/or modify
    % it under the terms of the GNU General Public License as published by
    % the Free Software Foundation; either version 2 of the License, or
    % (at your option) any later version.
    %
    % This program is distributed in the hope that it will be useful,
    % but WITHOUT ANY WARRANTY; without even the implied warranty of
    % MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    % GNU General Public License for more details.
    %
    % You should have received a copy of the GNU General Public License along
    % with this program; if not, write to the Free Software Foundation, Inc.,
    % 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
    %
    % This software tool was developed with support from the UK 
    % Engineering and Physical Sciences Council 
    % through  a studentship from the Institute of Chemical Biology 
    % and The Wellcome Trust through a grant entitled 
    % "The Open Microscopy Environment: Image Informatics for Biological Sciences" (Ref: 095931).
   
    properties(Constant)
        data_settings_filename = 'opt_tools_data_settings.xml';
    end
    
    properties(SetObservable = true)
            
        downsampling = 1;
        angle_downsampling = 1; 
        Z_range = []; 
        
        FBP_interp = 'linear';
        FBP_filter = 'Ram-Lak';
        FBP_fscaling = 1;    
                
    end                    
    
    properties(Transient)
        
        DefaultDirectory = ['C:' filesep];
        IcyDirectory = [];
        
        BatchDstDirectory = [];
        BatchSrcDirectory = [];        
        
        SrcDir = [];
        SrcFileList = [];
        DstDir = [];        
        
        current_filename = []; % not sure
        % current_metadata = [];
        
        file_names = [];
        omero_IDs = [];
        
        previous_filenames = [];
        previous_omero_IDs = [];
        
        angles; % well..
                
    end    
        
    properties(Transient,Hidden)
        % Properties that won't be saved to a data_settings_file etc.
        
        menu_controller;
        
        isGPU;
        
        proj; % native projection images (processed for co-registration and artifact correction)
        volm; % reconstructed volume
                               
    end
    
    events
        new_proj_set;
        new_volm_set;
        proj_clear;
        volm_clear;
        proj_and_volm_clear;
    end
            
    methods
        
        function obj = ic_OPTtools_data_controller(varargin)            
            %   
            handles = args2struct(varargin);
            assign_handles(obj,handles);            
                        
            addlistener(obj,'new_proj_set',@obj.on_new_proj_set);
            addlistener(obj,'new_volm_set',@obj.on_new_volm_set);                        
            addlistener(obj,'proj_clear',@obj.on_proj_clear);                        
            addlistener(obj,'volm_clear',@obj.on_volm_clear);            
            addlistener(obj,'proj_and_volm_clear',@obj.on_proj_and_volm_clear);                                    

            try 
            obj.load_settings;
            catch
            end
            
            if isempty(obj.IcyDirectory)
                hw = waitdialog('looking for Icy directory..');
                waitdialog(0.1,hw,'looking for Icy directory..');                
                if ispc
                       prevdir = pwd;
                       cd('c:\');
                       [~,b] = dos('dir /s /b icy.exe');
                       if ~strcmp(b,'File Not Found')
                            filenames = textscan(b,'%s','delimiter',char(10));
                            s = char(filenames{1});
                            s = s(1,:);
                            s = strsplit(s,'icy.exe');
                            obj.IcyDirectory = s{1};
                       end
                       cd(prevdir);
                elseif ismac
                    % to do
                else
                    % to do
                end                
                delete(hw); drawnow;
            end
            
            % detect GPU
            try
                isgpu = gpuDevice();
            catch    
            end                                  
            obj.isGPU = exist('isgpu','var');
                                                
        end
%-------------------------------------------------------------------------%                
        function save_settings(obj,~,~)        
            settings = [];
            settings.DefaultDirectory = obj.DefaultDirectory;
            settings.IcyDirectory = obj.IcyDirectory;
            settings.downsampling = obj.downsampling;
            settings.angle_downsampling = obj.angle_downsampling;            
            settings.FBP_interp = obj.FBP_interp;
            settings.FBP_filter = obj.FBP_filter;
            settings.FBP_fscaling = obj.FBP_fscaling;            
            xml_write([pwd filesep obj.data_settings_filename], settings);
        end % save_settings
%-------------------------------------------------------------------------%                        
        function load_settings(obj,~,~)        
             if exist([pwd filesep obj.data_settings_filename],'file') 
                [ settings, ~ ] = xml_read ([pwd filesep obj.data_settings_filename]);                                 
                obj.DefaultDirectory = settings.DefaultDirectory;  
                obj.IcyDirectory = settings.IcyDirectory;
                obj.downsampling = settings.downsampling;
                obj.angle_downsampling = settings.angle_downsampling;                
                obj.FBP_interp = settings.FBP_interp;
                obj.FBP_filter = settings.FBP_filter;
                obj.FBP_fscaling = settings.FBP_fscaling;                
             end
        end
%-------------------------------------------------------------------------%
        function infostring = Set_Src_Single(obj,full_filename,verbose,~)
            %   
            infostring = [];
            obj.angles = obj.get_angles(full_filename); % temp
            if isempty(obj.angles), 
                if verbose
                    errordlg('source does not contain angle specs - can not continue'), 
                end
                return, 
            end;
            %                               
            hw = [];
            waitmsg = 'Loading planes...';
            if verbose
                hw = waitdialog(waitmsg);
            end
            
            obj.proj = [];
            obj.volm = [];            
            notify(obj,'proj_and_volm_clear');                                                 
            
            try
            omedata = bfopen(full_filename);
            catch err
                errordlg(err.message);
                if ~isempty(hw)
                    delete(hw); 
                    drawnow;
                end
                return;
            end
            
            if ~isempty(omedata)

                imgdata = omedata{1,1};                
                n_planes = length(imgdata(:,1));
                                
                for p = 1 : n_planes,                    
                    plane = imgdata{p,1};
                    %   
                    if isempty(obj.proj)
                        [sizeX,sizeY] = size(plane);
                        obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
                        %
                        obj.current_filename = full_filename;
                        if isempty(obj.previous_filenames)
                            obj.previous_filenames{1} = obj.current_filename;
                        end                                                                                                
                    end %  ini - end
                    %
                    obj.proj(:,:,p) = plane;
                    %
                    if ~isempty(hw), waitdialog(p/n_planes,hw,waitmsg); drawnow, end;                    
                    %
                end
                                
                if ~isempty(hw), delete(hw), drawnow, end;
                
                % that might be inadequate for transmission...
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
%                  % invert if ???
%                  max_val = max(obj.proj(:));
%                  obj.proj = max_val - obj.proj;
                                 
                [filepath,~,~] = fileparts(full_filename);
                obj.DefaultDirectory = filepath;
            end
            
            % obj.data - do something dependent on downsampling... etc... 
            
            notify(obj,'new_proj_set');                        
            
            infostring = obj.current_filename;
            
        end
%-------------------------------------------------------------------------%
        function delete(obj)
            obj.save_settings;
        end
%-------------------------------------------------------------------------%        
        function FBP(obj,verbose,use_GPU)
            
            s = [];
            if use_GPU && obj.isGPU
                s = 'applying FBP (GPU) reconstruction.. please wait...';
            elseif ~use_GPU
                s = 'applying FBP reconstruction.. please wait...';
            else                     
                errordlg('can not run FBP (GPU) without GPU');
                return;
            end
            
            hw = [];
            if verbose
                hw = waitdialog(s);
            end
                                    
             obj.volm = [];                
             notify(obj,'volm_clear');

             [sizeX,sizeY,sizeZ] = size(obj.proj); 
             
             n_angles = numel(obj.angles);
             
             if sizeZ ~= n_angles
                 errormsg('Incompatible settings - can not continue');
                 return;
             end
                 
                 f = 1/obj.downsampling;
                 [szX_r,szY_r] = size(imresize(zeros(sizeX,sizeY),f));                 
             
                 step = obj.angle_downsampling;                 
                 acting_angles = obj.angles(1:step:n_angles);
                 %                                                   
                 y_min = 1;
                 y_max = sizeY;
                 YL = sizeY;
                 if ~isempty(obj.Z_range)
                     y_min = obj.Z_range(1);
                     y_max = obj.Z_range(2);
                     YL = y_max - y_min;                             
                 end                         
                                                   
                 if use_GPU && obj.isGPU 
                                          
                     if 1 == f % no downsampling

                         gpu_proj = gpuArray(cast(obj.proj(:,y_min:y_max,:),'single'));
                         gpu_volm = [];
                         
                         for y = 1 : YL                                       
                            sinogram = squeeze(gpu_proj(:,y,:));                             
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,YL))); % XYZ
                            end                            
                            gpu_volm(:,:,y) = reconstruction;                            
                            if ~isempty(hw), waitdialog(y/YL,hw,s); drawnow, end;
                         end                           
                         obj.volm = gather(gpu_volm);
                         
                     else % with downsampling                         
                         
                         proj_r = [];
                         gpu_volm = [];
                         
                         for r = 1:sizeZ,
                            if isempty(proj_r) 
                                [szX_r,szY_r] = size(imresize(obj.proj(:,y_min:y_max,r),f));
                                proj_r = zeros(szX_r,szY_r,sizeZ,'single');
                            end
                            proj_r(:,:,r) = imresize(obj.proj(:,y_min:y_max,r),f);
                         end
                         gpu_proj_r = gpuArray(proj_r);
                         clear('proj_r');                         
                         %
                         for y = 1 : szY_r 
                            sinogram = squeeze(gpu_proj_r(:,y,:));
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);                            
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,szY_r))); % XYZ
                            end                            
                            gpu_volm(:,:,y) = reconstruction;                            
                            if ~isempty(hw), waitdialog(y/szY_r,hw,s); drawnow, end;
                         end
                         obj.volm = gather(gpu_volm);
                         
                     end
                     
                 elseif ~use_GPU
                                          
                     if 1 == f % no downsampling
                                                                           
                         for y = 1 : YL                                       
                            sinogram = squeeze(double(obj.proj(:,y_min+y-1,:)));
                            % 
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
                            if isempty(obj.volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                obj.volm = zeros(sizeR1,sizeR2,YL); % XYZ
                            end
                            %
                            obj.volm(:,:,y) = reconstruction;
                            %
                            if ~isempty(hw), waitdialog(y/YL,hw,s); drawnow, end;
                         end                                                 
                         
                     else % with downsampling                         
                         
                         proj_r = [];
                         for r = 1:sizeZ,
                            if isempty(proj_r) 
                                [szX_r,szY_r] = size(imresize(obj.proj(:,y_min:y_max,r),f));
                                proj_r = zeros(szX_r,szY_r,sizeZ,'single');
                            end
                            proj_r(:,:,r) = imresize(obj.proj(:,y_min:y_max,r),f);
                         end
                         %
                         for y = 1 : szY_r 
                            sinogram = squeeze(double(proj_r(:,y,:)));                             
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);                            
                            if isempty(obj.volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                obj.volm = zeros(sizeR1,sizeR2,szY_r); % XYZ
                            end
                            %
                            obj.volm(:,:,y) = reconstruction;
                            %
                            if ~isempty(hw), waitdialog(y/szY_r,hw,s); drawnow, end;
                         end

                     end
                                      
                 end                     
                                                               
             obj.volm( obj.volm <= 0 ) = 0; % mm? 
             
             if ~isempty(hw), delete(hw), drawnow, end;
             
             notify(obj,'new_volm_set');
        end
%-------------------------------------------------------------------------%        
        function FBP_Largo(obj,~,~)
            
            if ~(1==obj.downsampling)
                 errordlg('only 1/1 proj-volm scale, full size, is supported, can not continue')
                 return; 
             end;     

             n_chunks = 10;
             %
             obj.volm = [];                
             notify(obj,'volm_clear');

             s1 = 'processing chunks & saving...';
             hw1 = waitdialog(s1);

             [~,sizeZ,~] = size(obj.proj); 
             
             maxV = -inf; 
             
             sz_chunk = floor(sizeZ/n_chunks);
             zrange(1)=1;
             zrange(2)=sz_chunk;
             k=0;
             while  zrange(2) < (sizeZ-sz_chunk)
                 %
                res = do_FBP_on_Z_chunk(obj,zrange,obj.isGPU);
                curmax = max(res(:));
                if curmax>maxV, maxV=curmax; end;
                res(res<0)=0;
                %
                zrange = zrange + sz_chunk;
                k=k+1;
                save(num2str(k),'res');
                waitdialog(k/(n_chunks+1),hw1,s1);
             end
             zrange_last(1) = zrange(2)+1;
             zrange_last(2) = sizeZ;
             %
             res = do_FBP_on_Z_chunk(obj,zrange_last,obj.isGPU);
             curmax = max(res(:));
             if curmax>maxV, maxV=curmax; end;
             res(res<0)=0;
             %
             k=k+1;
             save(num2str(k),'res');
             [szVx,szVy,~]=size(res);
             delete(hw1);drawnow;
             %
             try
                 obj.proj = [];
                 notify(obj,'proj_clear');
                 obj.volm = zeros(szVx,szVy,sizeZ,'uint16');
             catch
                 errordlg('memory allocation failed, can not continue');
                 return;
             end
             %
             s2 = 'retrieving chunks...';
             hw2 = waitdialog(s2);
             z_beg=1;
             for m=1:k
                 load(num2str(m));
                 [~,~,szVMz] = size(res);                 
                 obj.volm(:,:,z_beg:z_beg+szVMz-1) = cast(res*32767/maxV,'uint16');                
                 z_beg = z_beg+szVMz;
                 delete([num2str(m) '.mat']);
                 waitdialog(m/k,hw2,s2);
             end
             delete(hw2);drawnow;
             %
             obj.volm( obj.volm <= 0 ) = 0; % mm? 
             notify(obj,'new_volm_set');                                   
        end      
%-------------------------------------------------------------------------%
        function infostring  = OMERO_load_single(obj,omero_data_manager,verbose,~)
            
            infostring = [];            
            
            if ~isempty(omero_data_manager.dataset)
                image = select_Image(omero_data_manager.session,omero_data_manager.userid,omero_data_manager.dataset);
            else
                errordlg('Please set Dataset or Plate before trying to load images'); 
                return; 
            end;
            
            if isempty(image), return, end;

            angleS = obj.OMERO_get_angles(omero_data_manager,image);
            if isempty(angleS), errordlg('source does not contain angle specs - can not continue'), return, end;
                        
            infostring = obj.OMERO_load_image(omero_data_manager,image,verbose);
                        
        end
%-------------------------------------------------------------------------%
        function infostring  = OMERO_load_image(obj,omero_data_manager,image,verbose,~)
            
            omero_data_manager.image = image;
            
            obj.omero_IDs{1} = omero_data_manager.image.getId.getValue;
                             
            pixelsList = omero_data_manager.image.copyPixels();    
            pixels = pixelsList.get(0);
                        
            SizeZ = pixels.getSizeZ().getValue();
        
            pixelsId = pixels.getId().getValue();
            rawPixelsStore = omero_data_manager.session.createRawPixelsStore(); 
            rawPixelsStore.setPixelsId(pixelsId, false);    
                        
            obj.angles = obj.OMERO_get_angles(omero_data_manager,omero_data_manager.image);
            % if isempty(obj.angles), errordlg('source does not contain angle specs - can not continue'), return, end;
                                                    
            waitmsg = 'Loading planes form Omero, please wait ...';
            hw = [];
            if verbose
                hw = waitdialog(waitmsg);
            end            
                
            obj.proj = [];
            obj.volm = [];
            notify(obj,'proj_and_volm_clear');            
                
            n_planes = SizeZ;
                            
            for p = 1 : SizeZ,
                    
                    z = p-1;
                    c = 0;
                    t = 0;
                    rawPlane = rawPixelsStore.getPlane(z,c,t);                    
                    plane = toMatrix(rawPlane, pixels)';                     
                    %
                    if isempty(obj.proj)
                        [sizeX,sizeY] = size(plane);
                        obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));
                        
                    end %  ini - end
                    %
                    obj.proj(:,:,p) = plane;
                    %
                    if ~isempty(hw), waitdialog(p/n_planes,hw,waitmsg); drawnow, end;
                    %
            end

                % that might be inadequate for transmission...
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
%                  % invert if ???
%                  max_val = max(obj.proj(:));
%                  obj.proj = max_val - obj.proj;
                         
            delete(hw); drawnow;    

            rawPixelsStore.close();           
            
            notify(obj,'new_proj_set');                        
            
            % infostring
            try
                pName = char(java.lang.String(omero_data_manager.project.getName().getValue()));            
                pId = num2str(omero_data_manager.project.getId().getValue());                        
            catch
            end
            if ~exist('pName','var')
                pName = 'NO PROJECT!!';
                pId = 'xxx';
            end            
            dName = char(java.lang.String(omero_data_manager.dataset.getName().getValue()));                    
            iName = char(java.lang.String(omero_data_manager.image.getName().getValue()));            
            dId = num2str(omero_data_manager.dataset.getId().getValue());            
            iId = num2str(omero_data_manager.image.getId().getValue());            
            
            infostring = [ 'Image "' iName '" [' iId '] @ Dataset "' dName '" [' dId '] @ Project "' pName '" [' pId ']'];            
             
        end
        %-------------------------------------------------------------------------%
        function OMERO_load_multiple(obj,omero_data_manager,~)
            %
            % to do
            %
        end
                
         %------------------------------------------------------------------        
            function on_new_proj_set(obj, ~,~)
                set(obj.menu_controller.proj_label,'ForegroundColor','blue');
                set(obj.menu_controller.volm_label,'ForegroundColor','red');
            end            
         %------------------------------------------------------------------            
            function on_new_volm_set(obj, ~,~)
                set(obj.menu_controller.volm_label,'ForegroundColor','blue');                
            end
         %------------------------------------------------------------------            
            function on_proj_clear(obj, ~,~)
                set(obj.menu_controller.proj_label,'ForegroundColor','red');                
            end
         %------------------------------------------------------------------            
            function on_volm_clear(obj, ~,~)
                set(obj.menu_controller.volm_label,'ForegroundColor','red');                
            end
         %------------------------------------------------------------------            
            function on_proj_and_volm_clear(obj, ~,~)
                set(obj.menu_controller.volm_label,'ForegroundColor','red');                                
                set(obj.menu_controller.proj_label,'ForegroundColor','red');                                
            end
                        
%-------------------------------------------------------------------------%        
        function ret = get_angles(obj,full_filename,~)
            
            ret = [];
            
            try
            
                r = loci.formats.ChannelFiller();
                r = loci.formats.ChannelSeparator(r);

                OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
                r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
                r.setId(full_filename);
                %
                modlo = r.getModuloZ();
                if ~isempty(modlo)

                     if ~isempty(modlo.labels)
                         ret = str2num(modlo.labels)';
                     end

                     if ~isempty(modlo.start)
                         if modlo.end > modlo.start
                            nsteps = round((modlo.end - modlo.start)/modlo.step);
                            ret = 0:nsteps;
                            ret = ret*modlo.step;
                            ret = ret + modlo.start;
                         end
                     end
                     
                end
                        
            catch
            end
            
        end
        
%-------------------------------------------------------------------------%
        function ret = OMERO_get_angles(obj,omero_data_manager,image,~)
            
           ret = [];
     
           try
                            
                s = read_XmlAnnotation_havingNS(omero_data_manager.session,image,'openmicroscopy.org/omero/dimension/modulo');
                                                                                               
                if isempty(s), errordlg('no modulo annotation - can not continue'), return, end;

                [parseResult,~] = xmlreadstring(s);
                tree = xml_read(parseResult);
                if isfield(tree,'ModuloAlongZ')
                     modlo = tree.ModuloAlongZ;
                end;               

                if isfield(modlo.ATTRIBUTE,'Start')

                    start = modlo.ATTRIBUTE.Start;
                    step = modlo.ATTRIBUTE.Step;
                    e = modlo.ATTRIBUTE.End; 
                    nsteps = round((e - start)/step);
                    ret = 0:nsteps;
                    ret = ret*step;
                    ret = ret + start;

                else
                    if isnumeric(modlo.Label)
                        ret = modlo.Label;
                    else
                        ret = cell2mat(modlo.Label);
                    end
                end
            
            catch
            end
                        
        end        
        
%-------------------------------------------------------------------------%                
        function res = do_FBP_on_Z_chunk(obj,zrange,use_GPU)
                            
             res = [];
             if isempty(zrange) || 2~=numel(zrange) || ~(zrange(1)<zrange(2)) || ~(1==obj.downsampling)
                 return; 
             end;                             

             [sizeX,sizeY,sizeZ] = size(obj.proj); 
             
             n_angles = numel(obj.angles);
             
             if sizeZ ~= n_angles
                 errormsg('Incompatible settings - can not continue');
                 return;
             end
                              
                 step = obj.angle_downsampling;                 
                 acting_angles = obj.angles(1:step:n_angles);
                 %                                                   
                 y_min = zrange(1);
                 y_max = zrange(2);
                 YL = y_max - y_min;                             
                                                   
                 if use_GPU && obj.isGPU 
                                          
                         gpu_proj = gpuArray(cast(obj.proj(:,y_min:y_max,:),'single'));
                         gpu_volm = [];
                         
                         for y = 1 : YL                                       
                            sinogram = squeeze(gpu_proj(:,y,:));                             
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,YL))); % XYZ
                            end                            
                            gpu_volm(:,:,y) = reconstruction;                            
                         end                           
                         res = gather(gpu_volm);
                                              
                 elseif ~use_GPU
                                                                                                                     
                         for y = 1 : YL                                       
                            sinogram = squeeze(double(obj.proj(:,y_min+y-1,:)));
                            % 
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
                            if isempty(obj.volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                obj.volm = zeros(sizeR1,sizeR2,YL); % XYZ
                            end
                            %
                            res(:,:,y) = reconstruction;
                         end                                                                                                                
                 end                     
                                                               
             res( res <= 0 ) = 0; % mm? 
             
        end
        
%-------------------------------------------------------------------------%
        function run_batch(obj,omero_data_manager,mode,~)
                                    
            s1 = get(obj.menu_controller.menu_OMERO_Working_Data_Info,'Label');
            s2 = get(obj.menu_controller.menu_Batch_Indicator_Src,'Label');            
            if strcmp(s1,s2) && ~isempty(omero_data_manager.session) % images should be loaded from OMERO
                %
                imageList = getImages(omero_data_manager.session, 'dataset', omero_data_manager.dataset.getId.getValue);
                
                if isempty(imageList)
                    errordlg(['Dataset ' pName ' have no images'])
                    return;
                end;                                    
                        
                waitmsg = 'Batch processing...';
                hw = waitdialog(waitmsg);
                for k = 1:length(imageList) 
                        waitdialog((k-1)/length(imageList),hw,waitmsg); drawnow                    
                        infostring = obj.OMERO_load_image(omero_data_manager,imageList(k),false);
                        if ~isempty(infostring)                    
                            if strcmp(mode,'FBP')
                                obj.FBP(false,false);
                            elseif strcmp(mode,'FBP_GPU')
                                obj.FBP(false,true);
                            elseif strcmp(mode,'FBP_Largo')
                                obj.FBP_Largo;
                            end
                            %
                            % save volume on disk - presume OME.tiff filenames everywhere
                            iName = char(java.lang.String(imageList(k).getName().getValue()));                            
                            L = length(iName);
                            S = iName;
                            savefilename = [S(1:L-9) '_VOLUME.OME.tiff'];
                            [szX,szY,szZ] = size(obj.volm);
                            bfsave(reshape(obj.volm,[szX,szY,1,1,szZ]),[obj.BatchDstDirectory filesep savefilename], ...
                                                        'dimensionOrder','XYCTZ','Compression','LZW','BigTiff',true); 
                        end   
                        waitdialog(k/length(imageList),hw,waitmsg); drawnow
                end 
                delete(hw);drawnow;                  
                
            else % images should be loaded from HD
                
                if isdir(obj.BatchSrcDirectory)

                    files = dir([obj.BatchSrcDirectory filesep '*.OME.tiff']);
                    num_files = length(files);
                    if 0 ~= num_files
                        names_list = cell(1,num_files);
                        for k = 1:num_files
                            names_list{k} = char(files(k).name);
                        end
                    else
                        %? - can't arrive here?
                    end

                    waitmsg = 'Batch processing...';
                    hw = waitdialog(waitmsg);                    
                    for k=1:numel(names_list)
                        waitdialog((k-1)/numel(names_list),hw,waitmsg); drawnow;
                        fname = [obj.BatchSrcDirectory filesep names_list{k}];                    
                        infostring = obj.Set_Src_Single(fname,false);                        
                        if ~isempty(infostring)  
                            if strcmp(mode,'FBP')
                                obj.FBP(false,false);
                            elseif strcmp(mode,'FBP_GPU')
                                obj.FBP(false,true);
                            elseif strcmp(mode,'FBP_Largo')
                                obj.FBP_Largo;
                            end
                            %
                            % save volume on disk
                            L = length(names_list{k});
                            S = names_list{k};
                            savefilename = [S(1:L-9) '_VOLUME.OME.tiff'];
                            [szX,szY,szZ] = size(obj.volm);
                            bfsave(reshape(obj.volm,[szX,szY,1,1,szZ]),[obj.BatchDstDirectory filesep savefilename], ...
                                                        'dimensionOrder','XYCTZ','Compression','LZW','BigTiff',true);
                        end                    
                        waitdialog(k/numel(names_list),hw,waitmsg); drawnow;                                                                            
                    end
                    delete(hw);drawnow;

                else
                    %? - can't arrive here?
                end
                
            end 
            
        end
%-------------------------------------------------------------------------%        

    end
    
end