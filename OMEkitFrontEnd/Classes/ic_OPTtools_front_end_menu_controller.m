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
                
        menu_reconstruction_FBP;
        menu_reconstruction_FBP_GPU;
                        
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
            set(obj.menu_OMERO_Working_Data_Info,'Label','Working Data have not been set up','ForegroundColor','red');
        end                            
        %------------------------------------------------------------------
        function menu_OMERO_Connect_To_Logon_User_callback(obj,~,~)            
            obj.omero_data_manager.userid = obj.omero_data_manager.session.getAdminService().getEventContext().userId;
            obj.omero_data_manager.project = [];
            obj.omero_data_manager.dataset = [];
            set(obj.menu_OMERO_Working_Data_Info,'Label','Working Data have not been set up','ForegroundColor','red');
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
                obj.data_controller.Set_Src_Single([path file],true); % verbose
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
                    obj.data_controller.Set_Src_Single(char(obj.data_controller.previous_filenames{1}),true); % verbose
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
        function menu_OMERO_set_single_callback(obj, ~, ~)
            obj.data_controller.OMERO_load_single(obj.omero_data_manager);
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
        function menu_file_save_current_volume_callback(obj,~,~)
            if ~isempty(obj.data_controller.volm)
                [file, path] = uiputfile({'*.OME.tiff'},'Select exported acceptor image file name',obj.data_controller.DefaultDirectory);
                if file ~= 0                                    
                    bfsave(obj.data_controller.volm,[path filesep file],'Compression', 'LZW','BigTiff', true);   
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
                    icy_imshow(obj.data_controller.proj);
                catch 
                    msgbox('error - Icy might be not started');
                end
            end
        end
         %------------------------------------------------------------------        
        function menu_visualization_send_current_volm_to_Icy_callback(obj, ~,~)
            if ~isempty(obj.data_controller.volm)
                try
                    icy_im3show(obj.data_controller.volm);
                catch
                    msgbox('error - Icy might be not started');                    
                end
            end
        end        
         %------------------------------------------------------------------                
        function menu_visualization_setup_Icy_directory_callback(obj, ~,~)
            [path] = uigetdir(obj.data_controller.DefaultDirectory,'Guide to Icy directory');
            if path ~= 0
                obj.data_controller.IcyDirectory = path;                
            end                       
            try
                addpath([obj.data_controller.IcyDirectory filesep 'plugins' filesep 'ylemontag' filesep 'matlabcommunicator']);
                icy_init();
            catch
                errordlg('Icy directory not good or Matlab Communicator plugin is not installed - can not continue');
            end            
        end
         %------------------------------------------------------------------                
        function menu_visualization_start_Icy_callback(obj, ~,~)
            if ~isempty(obj.data_controller.IcyDirectory)
                dos([obj.data_controller.IcyDirectory filesep 'icy']);
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
        
    %================================= % downsampling indicators        
        % 
         %------------------------------------------------------------------
        function menu_settings_Pixel_Downsampling_1_callback(obj, ~,~)
            obj.data_controller.downsampling = 1;
            obj.data_controller.proj = []; obj.data_controller.volm = [];
            notify(obj.data_controller,'proj_and_volm_clear');
            set(obj.menu_settings_Pixel_Downsampling,'Label','Pixel downsampling 1/1');
        end        
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_2_callback(obj, ~,~)
            obj.data_controller.downsampling = 2;
            obj.data_controller.proj = []; obj.data_controller.volm = [];
            notify(obj.data_controller,'proj_and_volm_clear');
            set(obj.menu_settings_Pixel_Downsampling,'Label','Pixel downsampling 1/2');
        end
         %------------------------------------------------------------------
        function menu_settings_Pixel_Downsampling_4_callback(obj, ~,~)
            obj.data_controller.downsampling = 4;
            obj.data_controller.proj = []; obj.data_controller.volm = [];
            notify(obj.data_controller,'proj_and_volm_clear');
            set(obj.menu_settings_Pixel_Downsampling,'Label','Pixel downsampling 1/4');            
        end            
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_8_callback(obj, ~,~)
            obj.data_controller.downsampling = 8;
            obj.data_controller.proj = []; obj.data_controller.volm = [];
            notify(obj.data_controller,'proj_and_volm_clear');
            set(obj.menu_settings_Pixel_Downsampling,'Label','Pixel downsampling 1/8');                        
        end            
         %------------------------------------------------------------------        
        function menu_settings_Pixel_Downsampling_16_callback(obj, ~,~)
            obj.data_controller.downsampling = 16;
            obj.data_controller.proj = []; obj.data_controller.volm = []; 
            notify(obj.data_controller,'proj_and_volm_clear');
            set(obj.menu_settings_Pixel_Downsampling,'Label','Pixel downsampling 1/16');                                    
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
