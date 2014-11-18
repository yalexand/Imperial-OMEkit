
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

%             addpath('c:/users/yalexand/Icy/plugins/ylemontag/matlabcommunicator');
%             icy_init();
            try
                addpath([obj.IcyDirectory filesep 'plugins' filesep 'ylemontag' filesep 'matlabcommunicator']);
                icy_init();
            catch
                errordlg('Icy directory not good or Matlab Communicator plugin is not installed - can not continue');
            end
                                                
        end
%-------------------------------------------------------------------------%                
        function save_settings(obj,~,~)        
            settings = [];
            settings.DefaultDirectory = obj.DefaultDirectory;
            settings.IcyDirectory = obj.IcyDirectory;
            settings.downsampling = obj.downsampling;
            settings.angle_downsampling = obj.angle_downsampling;            
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
             end
        end
%-------------------------------------------------------------------------%
        function Set_Src_Single(obj,full_filename,verbose,~)
            %                                       
            obj.angles = obj.get_angles(full_filename); % temp
            if isempty(obj.angles), errordlg('source does not contain angle specs - can not continue'), return, end;
            %                               
            hw = [];
            if verbose
                hw = waitbar(0, 'Loading planes...');
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
                                
                f = 1./obj.downsampling;
                for p = 1 : n_planes,
                    plane = imgdata{p,1};
                    if 1 ~= f
                        plane = imresize(plane,f);
                    end;
                    %
                    if isempty(obj.proj)
                        [sizeX,sizeY] = size(plane);
                        sizeZ = n_planes;
                        sizeC = 1;
                        sizeT = 1;
                        obj.proj = zeros(sizeX,sizeY,sizeC,sizeZ,sizeT,class(plane)); % Icy likes XYCZT
                        %
                        obj.current_filename = full_filename;
                        if isempty(obj.previous_filenames)
                            obj.previous_filenames{1} = obj.current_filename;
                        end                                                                                                
                    end %  ini - end
                    %
                    obj.proj(:,:,1,p,1) = plane;
                    %
                    if ~isempty(hw), waitbar(p/n_planes,hw), drawnow, end;
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
        function FBP(obj,verbose,~)
            
            hw = [];
            if verbose
                hw = waitbar(0, 'applying FBP reconstruction.. please wait...');
            end
                        
             obj.volm = [];                
             notify(obj,'volm_clear');

             [sizeX,sizeY,sizeC,sizeZ,sizeT] = size(obj.proj); 
             
             n_angles = numel(obj.angles);
             
             if sizeZ ~= n_angles
                 errormsg('Incompatible settings - can not continue');
                 return;
             end
                 
                 step = obj.angle_downsampling;                 
                 acting_angles = obj.angles(1:step:n_angles);
                 sizeR = numel(acting_angles);
                 %
                 for y = 1 : sizeY                
                    % create sinogram 
                    sinogram = zeros(sizeX,sizeR,'double');                
                    for r = 1 : step : sizeR
                        sinogram(:,r) = sinogram(:,r) + double(obj.proj(:,y,sizeC,r,sizeT));
                    end
                    % reconstruction
                    reconstruction = iradon(sinogram,acting_angles,'linear','Ram-Lak');
                    if isempty(obj.volm)
                        [sizeR1,sizeR2] = size(reconstruction);
                        obj.volm = zeros(sizeR1,sizeR2,sizeY); % XYZ
                    end
                    %
                    obj.volm(:,:,y) = reconstruction;
                    %
                    if ~isempty(hw), waitbar(y/sizeY,hw), drawnow, end;
                 end                                                                    
             
             obj.volm( obj.volm <= 0 ) = 0; % mm? 
             
             if ~isempty(hw), delete(hw), drawnow, end;
             
             notify(obj,'new_volm_set');
        end
%-------------------------------------------------------------------------%
        function OMERO_load_single(obj,omero_data_manager,~)
                       
            if ~isempty(omero_data_manager.dataset)
                image = select_Image(omero_data_manager.session,omero_data_manager.userid,omero_data_manager.dataset);
            else
                errordlg('Please set Dataset or Plate before trying to load images'); 
                return; 
            end;
            
            if isempty(image), return, end;
            
            obj.omero_IDs{1} = image.getId.getValue;
                             
            pixelsList = image.copyPixels();    
            pixels = pixelsList.get(0);
                        
            SizeC = pixels.getSizeC().getValue();
            SizeZ = pixels.getSizeZ().getValue();
            SizeT = pixels.getSizeT().getValue();     
            SizeX = pixels.getSizeY().getValue();  
            SizeY = pixels.getSizeX().getValue();
        
            pixelsId = pixels.getId().getValue();
            rawPixelsStore = omero_data_manager.session.createRawPixelsStore(); 
            rawPixelsStore.setPixelsId(pixelsId, false);    
                        
            obj.angles = obj.OMERO_get_angles(omero_data_manager,image);
            if isempty(obj.angles), errordlg('source does not contain angle specs - can not continue'), return, end;
                                                    
            hw = waitbar(0, 'Loading planes form Omero, please wait ...');
                
            obj.proj = [];
            obj.volm = [];
            notify(obj,'proj_and_volm_clear');            
                
            n_planes = SizeZ;
                
            f = 1./obj.downsampling;
            for p = 1 : SizeZ,
                    
                    z = p-1;
                    c = 0;
                    t = 0;
                    rawPlane = rawPixelsStore.getPlane(z,c,t);                    
                    plane = toMatrix(rawPlane, pixels)'; 
                    
                    if 1 ~= f
                        plane = imresize(plane,f);
                    end;
                    %
                    if isempty(obj.proj)
                        [sizeX,sizeY] = size(plane);
                        sizeZ = n_planes;
                        sizeC = 1;
                        sizeT = 1;
                        obj.proj = zeros(sizeX,sizeY,sizeC,sizeZ,sizeT,class(plane)); % Icy likes XYCZT
                        
                    end %  ini - end
                    %
                    obj.proj(:,:,1,p,1) = plane;
                    %
                    if ~isempty(hw), waitbar(p/n_planes,hw), drawnow, end;
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
            
                % assigning angles via modulo annotation - start
                xas = getImageXmlAnnotations(omero_data_manager.session, image.getId.getValue);     

                is_modulo = false;
                for j = 1:numel(xas)
                        s = xas(j).getTextValue().getValue();
                        if ~isempty(strfind(s,'ModuloAlongZ')) && ~isempty(strfind(s,'OPT'))
                            is_modulo = true;
                            break;
                        end
                end           

                if ~is_modulo, errordlg('no modulo annotation - can not continue'), return, end;

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