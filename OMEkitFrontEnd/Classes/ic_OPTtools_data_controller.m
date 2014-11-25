
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
        % z_range = []; 
        
        FBP_interp = 'linear';
        FBP_filter = 'Ram-Lak';
        FBP_fscaling = 1;    
                
    end                    
    
    properties(Transient)
        
        DefaultDirectory = ['C:' filesep];
        IcyDirectory = [];
        
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
        new_batch_set;
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
            addlistener(obj,'new_batch_set',@obj.on_new_batch_set);   
                                    
            obj.load_settings;
            
            if isempty(obj.IcyDirectory)
                %
                % to do
                %
            end

            try
                addpath([obj.IcyDirectory filesep 'plugins' filesep 'ylemontag' filesep 'matlabcommunicator']);
                icy_init();
            catch
                errordlg('Icy directory not good or Matlab Communicator plugin is not installed - can not continue');
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
            obj.angles = obj.get_angles(full_filename); % temp
            if isempty(obj.angles), errordlg('source does not contain angle specs - can not continue'), return, end;
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
        function Set_Src_Multiple(obj,src_dir_path,~)
            disp(src_dir_path);
            %
            % todo
            %
            obj.DefaultDirectory = src_dir_path;
            % notify(obj,'new_batch_set'); % ?            
        end
%-------------------------------------------------------------------------%        
        function Set_Dst_Dir(obj,dst_dir_path,~)
            disp(dst_dir_path);
            %
            % todo
            %
            obj.DefaultDirectory = dst_dir_path;            
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
                 if use_GPU && obj.isGPU 
                                                              
                    % create downsampled projections
                    if 1 == f
                        gpu_proj = gpuArray(single(obj.proj));
                    else
                        proj_r = zeros(szX_r,szY_r,sizeZ);
                        for r = 1:sizeZ,
                            proj_r(:,:,r) = imresize(single(obj.proj(:,:,r)),f);
                        end
                        gpu_proj = gpuArray(proj_r);
                        clear('proj_r');
                    end
                                       
                    gpu_volm = [];                    
                                        
                    for y = 1 : szY_r                
                        sinogram = squeeze(gpu_proj(:,y,:));
                        % 
                        reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
                        if isempty(gpu_volm)
                            [sizeR1,sizeR2] = size(reconstruction);
                            gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,szY_r))); % XYZ
                        end
                        %
                        gpu_volm(:,:,y) = reconstruction;
                        %                        
                        if ~isempty(hw), waitdialog(y/szY_r,hw,s); drawnow, end;
                    end   
                     %
                     obj.volm = gather(gpu_volm);
                     
                 elseif ~use_GPU

                     obj.volm = [];
                     %
                     if 1 == f % no downsampling
                         for y = 1 : sizeY                                        
                            sinogram = squeeze(double(obj.proj(:,y,:)));
                            % 
                            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
                            if isempty(obj.volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                obj.volm = zeros(sizeR1,sizeR2,sizeY); % XYZ
                            end
                            %
                            obj.volm(:,:,y) = reconstruction;
                            %
                            if ~isempty(hw), waitdialog(y/sizeY,hw,s); drawnow, end;
                         end                                                 
                     else % with downsampling
                         proj_r = zeros(szX_r,szY_r,sizeZ,'single');
                         for r = 1:sizeZ,
                            proj_r(:,:,r) = imresize(obj.proj(:,:,r),f);
                         end
                         %
                         for y = 1 : szY_r
                            sinogram = squeeze(double(proj_r(:,y,:)));
                            % 
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
        function infostring  = OMERO_load_single(obj,omero_data_manager,verbose,~)

            infostring = [];            
            
            if ~isempty(omero_data_manager.dataset)
                image = select_Image(omero_data_manager.session,omero_data_manager.userid,omero_data_manager.dataset);
            else
                errordlg('Please set Dataset or Plate before trying to load images'); 
                return; 
            end;
            
            if isempty(image), return, end;
            
            omero_data_manager.image = image;
            
            obj.omero_IDs{1} = omero_data_manager.image.getId.getValue;
                             
            pixelsList = omero_data_manager.image.copyPixels();    
            pixels = pixelsList.get(0);
                        
            SizeZ = pixels.getSizeZ().getValue();
        
            pixelsId = pixels.getId().getValue();
            rawPixelsStore = omero_data_manager.session.createRawPixelsStore(); 
            rawPixelsStore.setPixelsId(pixelsId, false);    
                        
            obj.angles = obj.OMERO_get_angles(omero_data_manager,omero_data_manager.image);
            if isempty(obj.angles), errordlg('source does not contain angle specs - can not continue'), return, end;
                                                    
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
            pName = char(java.lang.String(omero_data_manager.project.getName().getValue()));            
            dName = char(java.lang.String(omero_data_manager.dataset.getName().getValue()));                    
            iName = char(java.lang.String(omero_data_manager.image.getName().getValue()));
            
            pId = num2str(omero_data_manager.project.getId().getValue());            
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
         %------------------------------------------------------------------            
            function on_new_batch_set(obj, ~,~)
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
    end
    
end