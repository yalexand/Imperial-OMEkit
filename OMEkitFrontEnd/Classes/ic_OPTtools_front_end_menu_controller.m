classdef ic_OPTtools_front_end_menu_controller < handle
        
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
    
    properties
        
        % indication
        proj_label;
        volm_label;
        batch_label;

        menu_file_Working_Data_Info;        
        menu_file_new_window;
        menu_file_set_src_single;
        menu_file_set_src_dir;
        menu_file_reset_previous;
        menu_file_set_dst_dir;
        menu_file_save_current_volume;
        
        menu_OMERO_login;
        menu_OMERO_Working_Data_Info;
        menu_OMERO_Set_Dataset;
        menu_OMERO_Switch_User;
        menu_OMERO_Connect_To_Another_User;
        menu_OMERO_Connect_To_Logon_User;
        menu_OMERO_Reset_Logon; 
            %
            menu_OMERO_set_single;
            menu_OMERO_set_multiple;
            menu_OMERO_reset_previous;        
        
        menu_settings_Pixel_Downsampling;
        menu_settings_Angle_Downsampling;

        menu_settings_Pixel_Downsampling_1;        
        menu_settings_Pixel_Downsampling_2;
        menu_settings_Pixel_Downsampling_4;
        menu_settings_Pixel_Downsampling_8;
        menu_settings_Pixel_Downsampling_16;

        menu_settings_Angle_Downsampling_1;        
        menu_settings_Angle_Downsampling_2;
        menu_settings_Angle_Downsampling_4;
        menu_settings_Angle_Downsampling_8;
        
        menu_settings_Zrange;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        menu_FBP_interp;   
        menu_FBP_interp_nearest;
        menu_FBP_interp_linear;
        menu_FBP_interp_spline;
        menu_FBP_interp_pchip;
        menu_FBP_interp_v5cubic;
    
        menu_FBP_filter;
        menu_FBP_filter_Ram_Lak;
        menu_FBP_filter_Shepp_Logan;
        menu_FBP_filter_Cosine;
        menu_FBP_filter_Hammming;
        menu_FBP_filter_Hann;
        menu_FBP_filter_None;
    
        menu_FBP_freq_scaling;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
        menu_reconstruction_FBP;
        menu_reconstruction_FBP_GPU;
        menu_reconstruction_FBP_Largo;
                        
        menu_visualization_setup_Icy_directory;
        menu_visualization_start_Icy;
        
        menu_visualization_send_current_proj_to_Icy;
        menu_visualization_send_current_volm_to_Icy;        

        % holy cows
        omero_data_manager;     
        data_controller;

    end
    
    properties(SetObservable = true)

    end
        
    methods
        
        %------------------------------------------------------------------        
        function obj = ic_OPTtools_front_end_menu_controller(handles)
            
            assign_handles(obj,handles);
            set_callbacks(obj);
            
            obj.data_controller.menu_controller = obj;
                                                                        
        end
        %------------------------------------------------------------------
        function set_callbacks(obj)
            
             mc = metaclass(obj);
             obj_prop = mc.Properties;
             obj_method = mc.Methods;
                          
             % Search for properties with corresponding callbacks
             for i=1:length(obj_prop)
                prop = obj_prop{i}.Name;
                if strncmp(prop,'menu_',5)
                    method = [prop '_callback'];
                    matching_methods = findobj([obj_method{:}],'Name',method);
                    if ~isempty(matching_methods)               
                        eval(['set(obj.' prop ',''Callback'',@obj.' method ')' ]);
                    end
                end          
             end
             
        end
        %------------------------------------------------------------------                                       
        function menu_file_new_window_callback(obj,~,~)
            ic_OPTtools();
        end
                        
        %------------------------------------------------------------------
        % OMERO
        %------------------------------------------------------------------
        function menu_OMERO_login_callback(obj,~,~)
            obj.omero_data_manager.Omero_logon();
            
            if ~isempty(obj.omero_data_manager.session)
                props = properties(obj);
                OMERO_props = props( strncmp('menu_OMERO',props,10) );
                for i=1:length(OMERO_props)
                    set(obj.(OMERO_props{i}),'Enable','on');
                end
            end            
        end
        %------------------------------------------------------------------
        function menu_OMERO_Set_Dataset_callback(obj,~,~)            
            infostring = obj.omero_data_manager.Set_Dataset();
            if ~isempty(infostring)
                set(obj.menu_OMERO_Working_Data_Info,'Label',infostring,'ForegroundColor','blue');
            end;
        end                        
        %------------------------------------------------------------------        
        function menu_OMERO_Reset_Logon_callback(obj,~,~)
            obj.omero_data_manager.Omero_logon();
        end
        %------------------------------------------------------------------        
        function menu_OMERO_Switch_User_callback(obj,~,~)
            %delete([ pwd '\' obj.omero_data_manager.omero_logon_filename ]);
            obj.omero_data_manager.Omero_logon_forced();
        end        
        %------------------------------------------------------------------
        function menu_OMERO_Connect_To_Another_User_callback(obj,~,~)
            obj.omero_data_manager.Select_Another_User();
            obj.omero_data_manager.project = [];
            obj.omero_data_manager.dataset = [];
            obj.data_controller.proj = [];
            obj.data_controller.volm = [];            
            notify(obj.data_controller,'proj_and_volm_clear');            
            set(obj.menu_OMERO_Working_Data_Info,'Label','...','ForegroundColor','red');
        end                            
        %------------------------------------------------------------------
        function menu_OMERO_Connect_To_Logon_User_callback(obj,~,~)            
            obj.omero_data_manager.userid = obj.omero_data_manager.session.getAdminService().getEventContext().userId;
            obj.omero_data_manager.project = [];
            obj.omero_data_manager.dataset = [];
            obj.data_controller.proj = [];
            obj.data_controller.volm = [];            
            notify(obj.data_controller,'proj_and_volm_clear');
            set(obj.menu_OMERO_Working_Data_Info,'Label','...','ForegroundColor','red');
        end  
         %------------------------------------------------------------------
        function menu_OMERO_set_single_callback(obj, ~, ~)
            infostring = obj.data_controller.OMERO_load_single(obj.omero_data_manager,true); % verbose
            if ~isempty(infostring)
                set(obj.menu_OMERO_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                set(obj.menu_file_Working_Data_Info,'Label','...','Enable','off');                
                obj.data_controller.current_filename = [];
                set(obj.menu_settings_Zrange,'Label','Z range : full');
                obj.data_controller.Z_range = []; % no selection                                    
            end;            
        end
         %------------------------------------------------------------------
        function menu_OMERO_set_multiple_callback(obj, ~, ~)
            obj.data_controller.OMERO_load_multiple(obj.omero_data_manager);
        end
         %------------------------------------------------------------------
        function menu_OMERO_reset_previous_callback(obj, ~, ~)            
            % to do            
        end                       
        
        %------------------------------------------------------------------
        % OMERO
        %------------------------------------------------------------------                                
                                        
         %------------------------------------------------------------------        
        function menu_tools_preferences_callback(obj,~,~)
            profile = ic_OPTtools_profile_controller();
            profile.set_profile();
        end        
         %------------------------------------------------------------------
        function menu_file_set_src_single_callback(obj, ~, ~)
            [file,path] = uigetfile({'*.OME.tiff','OME.tiff Files'},'Select OPT data file',obj.data_controller.DefaultDirectory);
            if file ~= 0
                infostring = obj.data_controller.Set_Src_Single([path file],true); % verbose
                if ~isempty(infostring)
                    set(obj.menu_file_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                    set(obj.menu_OMERO_Working_Data_Info,'Label','...','Enable','off');
                    set(obj.menu_settings_Zrange,'Label','Z range : full');
                    obj.data_controller.Z_range = []; % no selection                    
                    obj.omero_data_manager.image = [];
                end;                
            end
        end   
         %------------------------------------------------------------------
        function menu_file_set_src_dir_callback(obj, ~, ~)       
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Select a folder with OPT data files');
            if path ~= 0
                obj.data_controller.Set_Src_Multiple(path);    
            end
        end    
         %------------------------------------------------------------------
        function menu_file_reset_previous_callback(obj, ~, ~)       
            if ~isempty(obj.data_controller.previous_filenames) 
                if 1 == numel(obj.data_controller.previous_filenames) && ...
                   ~strcmp(obj.data_controller.current_filename,char(obj.data_controller.previous_filenames{1}))                
                    infostring = obj.data_controller.Set_Src_Single(char(obj.data_controller.previous_filenames{1}),true); % verbose
                    set(obj.menu_file_Working_Data_Info,'Label',infostring,'ForegroundColor','blue','Enable','on');
                    set(obj.menu_OMERO_Working_Data_Info,'Label','...','Enable','off');                    
                    set(obj.menu_settings_Zrange,'Label','Z range : full');
                    obj.data_controller.Z_range = []; % no selection                    
                end
            end            
        end
         %------------------------------------------------------------------
        function menu_file_set_dst_dir_callback(obj, ~, ~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Select a folder where to put reconstructed volume(s)');
            if path ~= 0
                obj.data_controller.Set_Dst_Dir(path);    
            end           
        end    
         %------------------------------------------------------------------       
        function menu_file_save_current_volume_callback(obj,~,~)
            if ~isempty(obj.data_controller.volm)
                [file, path] = uiputfile({'*.OME.tiff'},'Select exported acceptor image file name',obj.data_controller.DefaultDirectory);
                if file ~= 0  
                    hw = waitdialog(' ');
                    bfsave(obj.data_controller.volm,[path filesep file],'Compression', 'LZW','BigTiff', true); 
                    delete(hw);drawnow;
                end
            else
                errordlg('Volume was not created - nothing to save');
            end
        end
        
    %================================= % call Icy visualizations
        
         %------------------------------------------------------------------    
        function menu_OMERO_start_Icy_callback(obj, ~, ~)
            % to do
        end
         %------------------------------------------------------------------        
        function menu_visualization_send_current_proj_to_Icy_callback(obj, ~,~)
            if ~isempty(obj.data_controller.proj)
                try
                    f = 1/obj.data_controller.downsampling;
                    if 1 == f
                        [szX,szY,szR] = size(obj.data_controller.proj);
                        icy_imshow(reshape(obj.data_controller.proj,[szX,szY,1,szR,1]),['proj ' obj.get_current_data_info_string]); % Icy likes XYCZT 
                    else
                        [szX,szY] = size(imresize(obj.data_controller.proj(:,:,1),f));
                        [~,~,szR] = size(obj.data_controller.proj);
                        proj_r = zeros(szX,szY,1,szR,1,class(obj.data_controller.proj));
                        for r = 1:szR
                            proj_r(:,:,1,r,1) = imresize(obj.data_controller.proj(:,:,r),f);
                        end
                        icy_imshow(proj_r,['proj scale 1/' num2str(obj.data_controller.downsampling) ' : ' obj.get_current_data_info_string]); % Icy likes XYCZT 
                    end
                catch 
                    msgbox('error - Icy might be not started');
                end
            else
                msgbox('no projections - nothing to visualize');
            end
        end
         %------------------------------------------------------------------        
        function menu_visualization_send_current_volm_to_Icy_callback(obj, ~,~)
            if ~isempty(obj.data_controller.volm)
                try
                    icy_im3show(obj.data_controller.volm,['volm scale 1/' num2str(obj.data_controller.downsampling) ' : ' obj.get_current_data_info_string]);
                catch
                    msgbox('error - Icy might be not started');                    
                end
            else
                msgbox('no volume - nothing to visualize');
            end
        end        
         %------------------------------------------------------------------                
        function menu_visualization_setup_Icy_directory_callback(obj, ~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Guide to Icy directory');
            if path ~= 0
                obj.data_controller.IcyDirectory = path;                
            end                       
        end
         %------------------------------------------------------------------                
        function menu_visualization_start_Icy_callback(obj, ~,~)
            
            if ~isempty(obj.data_controller.IcyDirectory)                
                if ispc
                    dos([obj.data_controller.IcyDirectory filesep 'icy']);
                elseif ismac                    
                    unix(['open ' obj.data_controller.IcyDirectory filesep 'icy']); % ?                    
                elseif isunix
                    % ?
                end                                
            else
                msgbox('error - Icy directory was not set up');
            end
            
        end

    %================================= % reconstruction                
         %------------------------------------------------------------------        
        function menu_reconstruction_FBP_callback(obj, ~,~)
            if ~isempty(obj.data_controller.proj) && ~isempty(obj.data_controller.angles)
                obj.data_controller.FBP(true,false); % verbose, + no GPU
            else
                msgbox('data not loaded - can not do reconstruction');
            end            
        end        
         %------------------------------------------------------------------        
        function menu_reconstruction_FBP_GPU_callback(obj, ~,~)
            if ~isempty(obj.data_controller.proj) && ~isempty(obj.data_controller.angles)
                obj.data_controller.FBP(true,true); % verbose, + GPU
            else
                msgbox('data not loaded - can not do reconstruction');
            end            
        end                
         %------------------------------------------------------------------        
        function menu_reconstruction_FBP_Largo_callback(obj, ~,~)
            if ~isempty(obj.data_controller.proj) && ~isempty(obj.data_controller.angles)
                obj.data_controller.FBP_Largo;
            else
                msgbox('data not loaded - can not do reconstruction');
            end            
        end          
    %================================= % downsampling indicators        
        % 
         %------------------------------------------------------------------
        function menu_settings_Pixel_Downsampling_1_callback(obj, ~,~)
            obj.set_pixel_downsampling(1);            
        end        
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_2_callback(obj, ~,~)
            obj.set_pixel_downsampling(2);
        end
         %------------------------------------------------------------------
        function menu_settings_Pixel_Downsampling_4_callback(obj, ~,~)
            obj.set_pixel_downsampling(4);            
        end            
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_8_callback(obj, ~,~)
            obj.set_pixel_downsampling(8);            
        end            
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_16_callback(obj, ~,~)
            obj.set_pixel_downsampling(16);            
        end            
        %
         %------------------------------------------------------------------        
         function set_pixel_downsampling(obj,factor,~)
            obj.data_controller.downsampling = factor;
            obj.data_controller.volm = [];
            notify(obj.data_controller,'volm_clear');                        
            set(obj.menu_settings_Pixel_Downsampling,'Label',['Pixel downsampling : 1/' num2str(factor)]);                                                 
         end    
        %
         %------------------------------------------------------------------        
        function menu_settings_Angle_Downsampling_1_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 1;
            obj.data_controller.volm = []; notify(obj.data_controller,'volm_clear');
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/1');                                    
        end                    
         %------------------------------------------------------------------        
        function menu_settings_Angle_Downsampling_2_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 2;
            obj.data_controller.volm = []; notify(obj.data_controller,'volm_clear');
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/2');                                                
        end            
         %------------------------------------------------------------------        
        function menu_settings_Angle_Downsampling_4_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 4;
            obj.data_controller.volm = []; notify(obj.data_controller,'volm_clear'); 
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/4');                                                           
        end            
         %------------------------------------------------------------------
        function menu_settings_Angle_Downsampling_8_callback(obj, ~,~)
            obj.data_controller.angle_downsampling = 8;
            obj.data_controller.volm = []; notify(obj.data_controller,'volm_clear');
            set(obj.menu_settings_Angle_Downsampling,'Label','Angle downsampling 1/8');            
        end                    
         %------------------------------------------------------------------
        function menu_FBP_interp_nearest_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'nearest';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);
        end            
         %------------------------------------------------------------------        
        function menu_FBP_interp_linear_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'linear';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_interp_spline_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'spline';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_interp_pchip_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'pchip';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_interp_v5cubic_callback(obj, ~,~)
            obj.data_controller.FBP_interp = 'v5cubic';
            set(obj.menu_FBP_interp,'Label',['FBP interp : ' obj.data_controller.FBP_interp]);            
        end            
         %------------------------------------------------------------------                        
        function menu_FBP_filter_Ram_Lak_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Ram-Lak';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Shepp_Logan_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Shepp-Logan';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Cosine_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Cosine';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Hammming_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Hamming';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);            
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_Hann_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'Hann';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);                        
        end            
         %------------------------------------------------------------------                    
        function menu_FBP_filter_None_callback(obj, ~,~)
            obj.data_controller.FBP_filter = 'None';
            set(obj.menu_FBP_filter,'Label',['FBP filter : ' obj.data_controller.FBP_filter]);                        
        end            
         %------------------------------------------------------------------                        
        function menu_FBP_freq_scaling_callback(obj, ~,~)
            fscaling = enter_value();
            if ~isnan(fscaling) && fscaling > 0 && fscaling <= 1
                obj.data_controller.FBP_fscaling = fscaling;
                set(obj.menu_FBP_freq_scaling,'Label',['FBP fscaling : ' num2str(fscaling)]);                    
            end
        end            
         %------------------------------------------------------------------                
         function menu_settings_Zrange_callback(obj,~,~)
             if ~isempty(obj.data_controller.proj)
                h1 = figure;
                
                %imagesc(obj.data_controller.proj(:,:,1));
                [szX,szY,szR] = size(obj.data_controller.proj);
                for r = 1:10:szR
                     imagesc(obj.data_controller.proj(:,:,r));
                     daspect([1 1 1]);
                     getframe;
                end
                                                                    
                h = imrect; 
                position = wait(h); 
                try close(h1); catch, end;
                
                if ~isempty(position)                                        
                    position = fix(position);                    
                        minZ = position(1);
                        maxZ = position(1) + position(3);
                            if minZ <= 0, minZ = 1; end;
                            if maxZ > szY, maxZ = szY; end;                                        
                    obj.data_controller.Z_range = [minZ maxZ];

                    set(obj.menu_settings_Zrange,'Label',[ 'Z range ' '[' num2str(minZ) ',' num2str(maxZ) ']' ])
                else
                    msgbox('Z range will be switched to default (full data)');
                    set(obj.menu_settings_Zrange,'Label','Z range : full');
                    obj.data_controller.Z_range = []; % no selection
                end
                
             else
                 errordlg('please load projections first');
             end
                          
         end

        %------------------------------------------------------------------
        function infostring = get_current_data_info_string(obj,~,~)
            infostring = [];
            if ~isempty(obj.data_controller.current_filename)
                infostring = obj.data_controller.current_filename;
            elseif ~isempty(obj.omero_data_manager.image) 
                
                try
                    pName = char(java.lang.String(obj.omero_data_manager.project.getName().getValue()));            
                    pId = num2str(obj.omero_data_manager.project.getId().getValue());            
                catch
                end
                if ~exist('pName','var')
                    pName = 'NO PROJECT!!';
                    pId = 'xxx';
                end
                                                
                dName = char(java.lang.String(obj.omero_data_manager.dataset.getName().getValue()));                    
                iName = char(java.lang.String(obj.omero_data_manager.image.getName().getValue()));            
                    
                    dId = num2str(obj.omero_data_manager.dataset.getId().getValue());            
                    iId = num2str(obj.omero_data_manager.image.getId().getValue());                        
                infostring = [ 'Image "' iName '" [' iId '] @ Dataset "' dName '" [' dId '] @ Project "' pName '" [' pId ']'];            
            end
        end
         
    %================================= % VANITY       
    
        %------------------------------------------------------------------
        function menu_help_about_callback(obj, ~, ~)
            % to do
        end            
        %------------------------------------------------------------------
        function menu_help_tracker_callback(obj, ~, ~)
            % to do
        end            
        %------------------------------------------------------------------
        function menu_help_bugs_callback(obj, ~, ~)
            % to do
        end
                            
    end
    
end
