
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
        
        Reconstruction_Method = 'FBP';
        Reconstruction_GPU = 'OFF';
        Reconstruction_Largo = 'OFF';
        
        Prefiltering_Size = 'None';
        
        % TwIST
        TwIST_TAU = 0.0008; %1
        TwIST_LAMBDA = 1e-4; %2
        TwIST_ALPHA = 0; %3
        TwIST_BETA = 0; %4
        TwIST_STOPCRITERION = 1; %5
        TwIST_TOLERANCEA = 1e-4; %6      
        TwIST_TOLERANCED = 0.0001; %7
        TwIST_DEBIAS = 0; %8
        TwIST_MAXITERA = 10000; %9
        TwIST_MAXITERD = 200; %10
        TwIST_MINITERA = 5; %11
        TwIST_MINITERD = 5; %12
        TwIST_INITIALIZATION = 0; %13
        TwIST_MONOTONE = 1; %14
        TwIST_SPARSE = 1; %15
        TwIST_VERBOSE = 0; %16                               
        % TwIST        
        
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
        
        file_names = [];
        omero_IDs = [];
        
        previous_filenames = [];
        previous_omero_IDs = [];
        
        angles; 

        % current_metadata = []; % ?
        PixelsPhysicalSizeX = []; % as in loaded original
        PixelsPhysicalSizeY = [];
                        
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
        function set_TwIST_settings_default(obj,~,~)        
            obj.TwIST_TAU = 0.0008; %1
            obj.TwIST_LAMBDA = 1e-4; %2
            obj.TwIST_ALPHA = 0; %3
            obj.TwIST_BETA = 0; %4
            obj.TwIST_STOPCRITERION = 1; %5
            obj.TwIST_TOLERANCEA = 1e-4; %6      
            obj.TwIST_TOLERANCED = 0.0001; %7
            obj.TwIST_DEBIAS = 0; %8
            obj.TwIST_MAXITERA = 10000; %9
            obj.TwIST_MAXITERD = 200; %10
            obj.TwIST_MINITERA = 5; %11
            obj.TwIST_MINITERD = 5; %12
            obj.TwIST_INITIALIZATION = 0; %13
            obj.TwIST_MONOTONE = 1; %14
            obj.TwIST_SPARSE = 1; %15
            obj.TwIST_VERBOSE = 0; %16                                           
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
            
            settings.Reconstruction_Method =  obj.Reconstruction_Method;
            settings.Reconstruction_GPU =  obj.Reconstruction_GPU;
            settings.Reconstruction_Largo =  obj.Reconstruction_Largo;
            % TwIST
            settings.TwIST_TAU = obj.TwIST_TAU;
            settings.TwIST_LAMBDA = obj.TwIST_LAMBDA;
            settings.TwIST_ALPHA = obj.TwIST_ALPHA;
            settings.TwIST_BETA = obj.TwIST_BETA;
            settings.TwIST_STOPCRITERION = obj.TwIST_STOPCRITERION; 
            settings.TwIST_TOLERANCEA = obj.TwIST_TOLERANCEA; 
            settings.TwIST_TOLERANCED = obj.TwIST_TOLERANCED;
            settings.TwIST_DEBIAS = obj.TwIST_DEBIAS;
            settings.TwIST_MAXITERA = obj.TwIST_MAXITERA;
            settings.TwIST_MAXITERD = obj.TwIST_MAXITERD;
            settings.TwIST_MINITERA = obj.TwIST_MINITERA;
            settings.TwIST_MINITERD = obj.TwIST_MINITERD;
            settings.TwIST_INITIALIZATION = obj.TwIST_INITIALIZATION;
            settings.TwIST_MONOTONE = obj.TwIST_MONOTONE;
            settings.TwIST_SPARSE = obj.TwIST_SPARSE;
            settings.TwIST_VERBOSE = obj.TwIST_VERBOSE;
            % TwIST 
            
            settings.Prefiltering_Size = obj.Prefiltering_Size;
                        
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
                %
                obj.Reconstruction_Method = settings.Reconstruction_Method;
                obj.Reconstruction_GPU = settings.Reconstruction_GPU;
                obj.Reconstruction_Largo = settings.Reconstruction_Largo;
                % TwIST
                obj.TwIST_TAU = settings.TwIST_TAU;
                obj.TwIST_LAMBDA = settings.TwIST_LAMBDA;
                obj.TwIST_ALPHA = settings.TwIST_ALPHA;
                obj.TwIST_BETA = settings.TwIST_BETA;
                obj.TwIST_STOPCRITERION = settings.TwIST_STOPCRITERION; 
                obj.TwIST_TOLERANCEA = settings.TwIST_TOLERANCEA; 
                obj.TwIST_TOLERANCED = settings.TwIST_TOLERANCED;
                obj.TwIST_DEBIAS = settings.TwIST_DEBIAS;
                obj.TwIST_MAXITERA = settings.TwIST_MAXITERA;
                obj.TwIST_MAXITERD = settings.TwIST_MAXITERD;
                obj.TwIST_MINITERA = settings.TwIST_MINITERA;
                obj.TwIST_MINITERD = settings.TwIST_MINITERD;
                obj.TwIST_INITIALIZATION = settings.TwIST_INITIALIZATION;
                obj.TwIST_MONOTONE = settings.TwIST_MONOTONE;
                obj.TwIST_SPARSE = settings.TwIST_SPARSE;
                obj.TwIST_VERBOSE = settings.TwIST_VERBOSE;
                % TwIST                        
                
                obj.Prefiltering_Size = settings.Prefiltering_Size;
             end
        end
%-------------------------------------------------------------------------%
        function infostring = Set_Src_Single(obj,full_filename,verbose,~)
            %
            obj.proj = [];
            obj.volm = [];            
            obj.on_proj_and_volm_clear;            
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
                                
            r = loci.formats.ChannelFiller();
            r = loci.formats.ChannelSeparator(r);
            OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
            r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
            r.setId(full_filename);
            r.setSeries(0);            
            omeMeta = r.getMetadataStore();             
            obj.PixelsPhysicalSizeX = omeMeta.getPixelsPhysicalSizeX(0).getValue;
            obj.PixelsPhysicalSizeY = omeMeta.getPixelsPhysicalSizeY(0).getValue;
                                                                    
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
                        if isnumeric(obj.Prefiltering_Size)
                            s = obj.Prefiltering_Size;
                            obj.proj(:,:,p) = medfilt2(plane,'symmetric',[s s]);
                        else
                            obj.proj(:,:,p) = plane;
                        end
                        %
                    if ~isempty(hw), waitdialog(p/n_planes,hw,waitmsg); drawnow, end;                    
                    %
                end                                
                if ~isempty(hw), delete(hw), drawnow, end;
                
                % possibly correcting orientation
                if ~obj.proj_rect_orientation_is_OK % needs to reload with swapped dims
                    %
                    waitmsg = 'Oops.. swappig dimensions..';
                    if verbose
                        hw = waitdialog(waitmsg);
                    end
                    %
                    obj.proj = [];                  
                    %
                    for p = 1 : n_planes,                    
                        plane = rot90(imgdata{p,1});
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
                        if isnumeric(obj.Prefiltering_Size)
                            s = obj.Prefiltering_Size;
                            obj.proj(:,:,p) = medfilt2(plane,'symmetric',[s s]);
                        else
                            obj.proj(:,:,p) = plane;
                        end
                        %
                        if ~isempty(hw), waitdialog(p/n_planes,hw,waitmsg); drawnow, end;                    
                        %
                    end                                
                    if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                    %
                end
                % end orientation correcting...
                
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
                        
            obj.on_new_proj_set;
            
            infostring = obj.current_filename;
            
        end
%-------------------------------------------------------------------------%
function save_volume(obj,full_filename,verbose,~)                        
    hw = [];   
    if verbose, hw = waitdialog(' '); end;                    
    %
    % mat-file
    if ~isempty(strfind(lower(full_filename),'.mat'))
        %
        vol = obj.volm;
        save(full_filename,'vol','-v7.3');
        clear('vol');
    elseif ~isempty(strfind(lower(full_filename),'.ome.tiff'))
    %
        [szX,szY,szZ] = size(obj.volm);                                        
        if ~isempty(obj.PixelsPhysicalSizeX) && ~isempty(obj.PixelsPhysicalSizeX)
            metadata = createMinimalOMEXMLMetadata(reshape(obj.volm,[szX,szY,1,1,szZ]),'XYCTZ');
            toPosFloat = @(x) ome.xml.model.primitives.PositiveFloat(java.lang.Double(x));
            metadata.setPixelsPhysicalSizeX(toPosFloat(obj.PixelsPhysicalSizeX*obj.downsampling),0);
            metadata.setPixelsPhysicalSizeY(toPosFloat(obj.PixelsPhysicalSizeY*obj.downsampling),0);
            metadata.setPixelsPhysicalSizeZ(toPosFloat(obj.PixelsPhysicalSizeX*obj.downsampling),0);                        
            bfsave(reshape(obj.volm,[szX,szY,1,1,szZ]),full_filename,'metadata',metadata,'Compression','LZW','BigTiff',true); 
        else
            bfsave(reshape(obj.volm,[szX,szY,1,1,szZ]),full_filename,'dimensionOrder','XYCTZ','Compression','LZW','BigTiff',true); 
        end                    
    end
    if verbose, delete(hw), drawnow; end;
end
%-------------------------------------------------------------------------%
        function res = proj_rect_orientation_is_OK(obj,~,~)
            
            [sizeX,sizeY,n_planes] = size(obj.proj);
             
            ps1_acc = [];
            for k=1:2:sizeY
                s1 = squeeze(double(obj.proj(:,k,:)));
                s = sum(s1);
                F = fftshift(fft(s));
                ps = F.*conj(F);                
                if isempty(ps1_acc) ps1_acc = zeros(size(ps)); end;
                ps1_acc = ps1_acc + ps;
            end
            %
            ps2_acc = [];
            for k=1:2:sizeX
                s2 = squeeze(double(obj.proj(k,:,:)));
                s = sum(s2);
                F = fftshift(fft(s));
                ps = F.*conj(F);                
                if isempty(ps2_acc) ps2_acc = zeros(size(ps)); end;
                ps2_acc = ps2_acc + ps;
            end
            %
            ps1_acc = ps1_acc/(sizeY/2);
            ps2_acc = ps2_acc/(sizeX/2);
            %
            N = fix(length(ps1_acc))/2;            
            %                        
            y1 = ps1_acc(N+2:2*N);
            y2 = ps2_acc(N+2:2*N);            
            
            discr_param = mean(log(y2./y1));
            
%             figure();
%             plot((1:N-1),log(y1),'b.-',(1:N-1),log(y2),'r.-');
%             xlabel(num2str(discr_param));
            
            res = true;
            if (discr_param < 0), res = false; end;
                                                               
        end
%-------------------------------------------------------------------------%
        function delete(obj)
            obj.save_settings;
        end
%-------------------------------------------------------------------------%        
        function reconstruction = FBP(obj,sinogram,~)
            step = obj.angle_downsampling;                 
            n_angles = numel(obj.angles);
            acting_angles = obj.angles(1:step:n_angles);
            reconstruction = iradon(sinogram,acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling);
        end        
%-------------------------------------------------------------------------%        
        function reconstruction = FBP_TwIST(obj,sinogram,~)
                                    
            step = obj.angle_downsampling;                 
            n_angles = numel(obj.angles);
            acting_angles = obj.angles(1:step:n_angles);            
            %
            [N,~] = size(sinogram);            
            
            % denoising function;    %Change if necessary - strength of total variarion
            tv_iters = 5;            
            Psi = @(x,th)  tvdenoise(x,2/th,tv_iters);
            % 
            hR = @(x)  radon(x, acting_angles);
            hRT = @(x) iradon(x, acting_angles,obj.FBP_interp,obj.FBP_filter,obj.FBP_fscaling,N);

            if strcmp(obj.Reconstruction_GPU,'OFF')
                
                % set the penalty function, to compute the objective
                Phi = @(x) TVnorm(x);
                tau = obj.TwIST_TAU;
                % input (zero-padded) sinogram  
                y = obj.zero_pad_sinogram_for_iradon(sinogram);

                 [reconstruction,dummy1,obj_twist,...
                    times_twist,dummy2,mse_twist]= ...
                         TwIST(y,hR,...
                         tau,...
                         'AT', hRT, ...
                         'Psi', Psi, ...
                         'Phi',Phi, ...
                         'Lambda', obj.TwIST_LAMBDA, ...                     
                         'Monotone',obj.TwIST_MONOTONE,...
                         'MAXITERA', obj.TwIST_MAXITERA, ...
                         'MAXITERD', obj.TwIST_MAXITERD, ...                     
                         'Initialization',obj.TwIST_INITIALIZATION,...
                         'StopCriterion',obj.TwIST_STOPCRITERION,...
                         'ToleranceA',obj.TwIST_TOLERANCEA,...
                         'ToleranceD',obj.TwIST_TOLERANCED,...
                         'Verbose', obj.TwIST_VERBOSE);
                     
            else % if strcmp(obj.Reconstruction_GPU,'ON') && obj.isGPU
                % cheating - still not clear why TwIST_gpu fails on GPU
                reconstruction = obj.FBP(sinogram);
            end
        end        
%-------------------------------------------------------------------------%        
%-------------------------------------------------------------------------%
        function perform_reconstruction(obj,verbose,~)
            
            use_GPU = strcmp(obj.Reconstruction_GPU,'ON');
                        
            RF = []; % reconstruction function
            if strcmp(obj.Reconstruction_Method,'FBP')
                RF = @obj.FBP;
            elseif ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                RF = @obj.FBP_TwIST;
            else
                % shouldn't come here
                return;
            end
                                                            
            obj.volm = [];                
            obj.on_volm_clear;

            [sizeX,sizeY,sizeZ] = size(obj.proj); 
             
            n_angles = numel(obj.angles);
             
            if sizeZ ~= n_angles
                errormsg('Incompatible settings - can not continue');
                return;
            end
                                    
            s = [];
            if use_GPU && obj.isGPU
                s = [obj.Reconstruction_Method ' GPU reconstruction.. please wait...'];
            elseif ~use_GPU
                s = [obj.Reconstruction_Method ' reconstruction.. please wait...'];
            else                     
                errordlg('can not run FBP (GPU) without GPU');
                return;
            end
                          
            hw = [];
            if verbose
                hw = waitdialog(s);
            end
                          
            f = 1/obj.downsampling;
            [szX_r,szY_r] = size(imresize(zeros(sizeX,sizeY),f));                 
             
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
                            reconstruction = RF(sinogram);
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
                            reconstruction = RF(sinogram);                            
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
                            reconstruction = RF(sinogram);
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
                            reconstruction = RF(sinogram);                                                        
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
             
             obj.on_new_volm_set;
        end
%-------------------------------------------------------------------------% 
function padded_sinogram = zero_pad_sinogram_for_iradon(obj,sinogram,~)
            
           [N,n_angles] = size(sinogram);
           szproj = [N N];
            
           zpt = ceil((2*ceil(norm(szproj-floor((szproj-1)/2)-1))+3 - N)/2);
           zpb = floor((2*ceil(norm(szproj-floor((szproj-1)/2)-1))+3 - N)/2);
           %st = abs(zpb - zpt); 
                        
           R = single(padarray(sinogram,[zpt 0], 'replicate' ,'pre'));
           R = single(padarray(R,[zpb 0], 'replicate' ,'post'));                                                                                                                                   
           padded_sinogram = R;                                                
end
%-------------------------------------------------------------------------% 
        function perform_reconstruction_Largo(obj,~)            

             if 1 ~= obj.downsampling
                 errordlg('only 1/1 proj-volm scale, full size, is supported, can not continue')
                 return; 
             end;     

             obj.volm = [];                
             obj.on_volm_clear;
             [~,sizeZ,~] = size(obj.proj);              
             
             maxV = -inf;              
             
             % not hooked
             Max_vox_chunk = 71*1e6;
             n_chunks = floor(numel(obj.proj(:))/Max_vox_chunk);                          
             if n_chunks <= 1, n_chunks = 2; end;
                          
             n_chunks = 8;             
             
             sz_chunk = floor(sizeZ/n_chunks);             
             %
             rest_z = mod(sizeZ,n_chunks);
             % 
             z2 = (1:n_chunks)*sz_chunk;
             z1 = z2 - sz_chunk+1;
             zranges = [z1;z2]';
                           
             if 0~=rest_z
                  lastel = zranges(n_chunks,:);
                  lastel(1) = lastel(2) + 1;
                  lastel(2) = lastel(2) + rest_z;                  
                  zranges = [zranges; lastel];
             end
              
             s1 = 'processing chunks & saving...';
             hw1 = waitdialog(s1);
             sz = size(zranges);
             n_blocks = sz(1);
             for k = 1 : n_blocks
                    waitdialog((k-1)/n_blocks,hw1,s1);                                  
                res = obj.do_reconstruction_on_Z_chunk(zranges(k,:));
                curmax = max(res(:));
                if curmax>maxV, maxV=curmax; end;
                res(res<0)=0;
                save(num2str(k),'res');
                    waitdialog(k/n_blocks,hw1,s1);                 
             end
             delete(hw1);drawnow;
                 
             [szVx,szVy,~]=size(res);
             
             try
                 obj.proj = [];                 
                 obj.on_proj_clear;
                 obj.volm = zeros(szVx,szVy,sizeZ,'uint16');
             catch
                 errordlg('memory allocation failed, can not continue');
                 return;
             end
             %
             s2 = 'retrieving chunks...';
             hw2 = waitdialog(s2);
             for k=1:n_blocks
                 waitdialog((k-1)/n_blocks,hw2,s2);
                 load(num2str(k));
                 obj.volm(:,:,zranges(k,1):zranges(k,2)) = cast(res*32767/maxV,'uint16');                
                 delete([num2str(k) '.mat']);
                 waitdialog(k/n_blocks,hw2,s2);
             end
             delete(hw2);drawnow;
             %
             obj.volm( obj.volm <= 0 ) = 0; % mm? 
             obj.on_new_volm_set;
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
            
            obj.PixelsPhysicalSizeX = pixels.getPhysicalSizeX.getValue;
            obj.PixelsPhysicalSizeY = pixels.getPhysicalSizeY.getValue;
        
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
            obj.on_proj_and_volm_clear;
                
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
                        if isnumeric(obj.Prefiltering_Size)
                            s = obj.Prefiltering_Size;
                            obj.proj(:,:,p) = medfilt2(plane,'symmetric',[s s]);
                        else
                            obj.proj(:,:,p) = plane;
                        end
                    %
                    if ~isempty(hw), waitdialog(p/n_planes,hw,waitmsg); drawnow, end;
                    %
            end
            if ~isempty(hw), delete(hw), drawnow; end;   
            
                % possibly correcting orientation
                if ~obj.proj_rect_orientation_is_OK % needs to reload with swapped dims
                    %
                    waitmsg = 'Oops.. swappig dimensions..';
                    if verbose
                        hw = waitdialog(waitmsg);
                    end
                    %
                    obj.proj = [];                  
                    %
                    for p = 1 : SizeZ,
                            z = p-1;
                            c = 0;
                            t = 0;
                            rawPlane = rawPixelsStore.getPlane(z,c,t);                    
                            plane = rot90(toMatrix(rawPlane, pixels)');
                            %
                            if isempty(obj.proj)
                                [sizeX,sizeY] = size(plane);
                                obj.proj = zeros(sizeX,sizeY,n_planes,class(plane));

                            end %  ini - end
                            %
                            if isnumeric(obj.Prefiltering_Size)
                                s = obj.Prefiltering_Size;
                                obj.proj(:,:,p) = medfilt2(plane,'symmetric',[s s]);
                            else
                                obj.proj(:,:,p) = plane;
                            end
                            %
                            if ~isempty(hw), waitdialog(p/n_planes,hw,waitmsg); drawnow, end;
                            %
                    end                          
                    if ~isempty(hw), delete(hw), drawnow, end;                                                                                
                    %
                end
            
                % that might be inadequate for transmission...
                if min(obj.proj(:)) > 2^15
                    obj.proj = obj.proj - 2^15;    % clear the sign bit which is set by labview
                end
%                  % invert if ???
%                  max_val = max(obj.proj(:));
%                  obj.proj = max_val - obj.proj;
                         
            rawPixelsStore.close();           
            
            obj.on_new_proj_set;
            
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
        function res = do_reconstruction_on_Z_chunk(obj,zrange)
                        
             RF = []; % reconstruction function
             if strcmp(obj.Reconstruction_Method,'FBP')            
                RF = @obj.FBP;
             elseif ~isempty(strfind(obj.Reconstruction_Method,'TwIST'))
                RF = @obj.FBP_TwIST;
             end
                        
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
                 YL = y_max - y_min + 1; % mmmm
                                                   
                 if strcmp(obj.Reconstruction_GPU,'ON') && obj.isGPU 
                                          
                         gpu_proj = gpuArray(cast(obj.proj(:,y_min:y_max,:),'single'));
                         gpu_volm = [];
                         
                         for y = 1 : YL                                       
                            sinogram = squeeze(gpu_proj(:,y,:));                             
                            reconstruction = RF(sinogram);
                            if isempty(gpu_volm)
                                [sizeR1,sizeR2] = size(reconstruction);
                                gpu_volm = gpuArray(single(zeros(sizeR1,sizeR2,YL))); % XYZ
                            end                            
                            gpu_volm(:,:,y) = reconstruction;                            
                         end                           
                         res = gather(gpu_volm);
                                              
                 elseif strcmp(obj.Reconstruction_GPU,'OFF')
                                                                                                                     
                         for y = 1 : YL                                       
                            sinogram = squeeze(double(obj.proj(:,y_min+y-1,:)));
                            % 
                            reconstruction = RF(sinogram);
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
        function run_batch(obj,omero_data_manager,~)
                                                  
            if strcmp(obj.Reconstruction_Largo,'ON') && 1 ~= obj.downsampling
                errordlg('only 1/1 proj-volm scale, full size, is supported, can not continue');
                return;                     
            end
            %                                               
            s1 = get(obj.menu_controller.menu_OMERO_Working_Data_Info,'Label');
            s2 = get(obj.menu_controller.menu_Batch_Indicator_Src,'Label');            
            if strcmp(s1,s2) && ~isempty(omero_data_manager.session) % images should be loaded from OMERO
                %
                imageList = getImages(omero_data_manager.session, 'dataset', omero_data_manager.dataset.getId.getValue);
                
                if isempty(imageList)
                    errordlg(['Dataset ' pName ' have no images'])
                    return;
                end;
                %
                waitmsg = 'Batch processing...';
                hw = waitdialog(waitmsg);
                for k = 1:length(imageList) 
                        waitdialog((k-1)/length(imageList),hw,waitmsg); drawnow                    
                        infostring = obj.OMERO_load_image(omero_data_manager,imageList(k),false);
                        if ~isempty(infostring)                    
                            if strcmp(obj.Reconstruction_Largo,'ON')
                                obj.perform_reconstruction_Largo;
                            else
                                obj.perform_reconstruction(false);
                            end
                            %
                            % save volume on disk - presume OME.tiff filenames everywhere
                            iName = char(java.lang.String(imageList(k).getName().getValue()));                            
                            L = length(iName);
                            savefilename = [iName(1:L-9) '_VOLUME.OME.tiff'];
                            obj.save_volume([obj.BatchDstDirectory filesep savefilename],false); % silent
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
                            if strcmp(obj.Reconstruction_Largo,'ON')
                                obj.perform_reconstruction_Largo;
                            else
                                obj.perform_reconstruction(false);
                            end
                            %
                            % save volume on disk
                            iName = names_list{k};
                            L = length(iName);
                            savefilename = [iName(1:L-9) '_VOLUME.OME.tiff'];
                            obj.save_volume([obj.BatchDstDirectory filesep savefilename],false); % silent
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