classdef ic_converter_impl < handle
        
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
        
        window;
        gui; % the thing guidata returns
        bckg_color;
        DefaultDataDirectory;
                
        % set by user
        Dst = [];
        Src = [];
        SrcList = []; % directory   
        
        excel_path = [];
        
        % set by user
        Modulo = 'ModuloAlongT';        % ModuloAlongZ,C,T
        Variable = 'lifetime';          % running variable: lifetime, angle, Yvar, Xvar, wavelength (C), (Z,T,P?) 
        Units = 'ps';                   % angle, rad, pixel        
        Extension = 'tif';              % source files' extension        
        FLIM_mode = 'Time Gated';       % TCSPC, TCSPC non-imaging, TimeGated, None         
        %                     
        Modulo_popupmenu_str = {'ModuloAlongZ','ModuloAlongC','ModuloAlongT','none'};
        Variable_popupmenu_str = {'lifetime', 'angle', 'Yvar', 'Xvar', 'wavelength','none'};
        Units_popupmenu_str = {'ps','ns','degree','radian','nm','pixel','none'};
        FLIM_mode_popupmenu_str = {'TCSPC', 'TCSPC non-imaging', 'Time Gated', 'Time Gated non-imaging','none'};        
        %
        Extension_popupmenu_str = {'tif','txt','jpg','png','bmp','gif'};                                                
    end
    
    methods
%-------------------------------------------------------------------------%      
    function obj = ic_converter_impl()
        
        
            %profile = profile_controller();
            % profile.load_profile();
        
                                                
%           obj.Extension = '???';
            obj.bckg_color = [.8 .8 .8]; 
            obj.DefaultDataDirectory = 'C:\';
            
            obj.window = figure( ...
                'Name', 'Imperial College OME.tiff converter', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'Position', [0 0 970 120], ...                
                'Toolbar', 'none', ...
                'DockControls', 'off', ...                
                'Resize', 'off', ...                
                'HandleVisibility', 'off', ...
                'Visible','off');

            ic_width = 600;
            %ic_height = ceil(ic_width/1.618);
            ic_height = ceil(ic_width/1.8 );
            set(obj.window,'OuterPosition',[1 1 ic_width ic_height]);
           
            handles = guidata(obj.window);                                                       
            handles.window = obj.window;
                                                           
            handles = obj.setup_layout(handles);   
            handles = obj.setup_menu(handles);
                        
            guidata(obj.window,handles);
            obj.gui = guidata(obj.window);
            
            if exist([pwd filesep 'ic_converter_settings.xml'],'file') 
                [ settings, ~ ] = xml_read ('ic_converter_settings.xml');                    
                %
                obj.DefaultDataDirectory = settings.DefaultDataDirectory;        
                obj.Modulo = settings.Modulo;                             
                obj.Variable = settings.Variable;
                obj.Units = settings.Units;        
                obj.FLIM_mode = settings.FLIM_mode;
                obj.Extension = settings.Extension;   
                %
                obj.set_gui_string_item('Modulo_popupmenu',obj.Modulo);
                obj.set_gui_string_item('Variable_popupmenu',obj.Variable);
                obj.set_gui_string_item('Units_popupmenu',obj.Units);
                obj.set_gui_string_item('FLIM_mode_popupmenu',obj.FLIM_mode);
                obj.set_gui_string_item('Extension_popupmenu',obj.Extension);         
                
                if isfield(settings,'SPW_mode')
                    set(obj.gui.SPW_check,'Value',settings.SPW_mode);   
                end                
                if isfield(settings,'excel_path') && ~isempty(settings.excel_path)
                    obj.excel_path = settings.excel_path;   
                end                                
            end
                                    
            close all;            
            set(obj.window,'Visible','on');
            set(obj.window,'CloseRequestFcn',@obj.close_request_fcn); 
            %
            wait = false;
            
            if ~isdeployed
                addpath_OMEkit;
                javaaddpath(fullfile([pwd filesep 'FileWriteSPW' filesep 'dist'],'FileWriteSPW.jar'));
            else
                wait = true;
            end            
                        
            if wait
                waitfor(obj.window);
            end
            %                                
            % verify that enough memory is allocated
            bfCheckJavaMemory(); 
            % load the Bio-Formats library into the MATLAB environment
            bfCheckJavaPath(true);
            % ini logging
            loci.common.DebugTools.enableLogging('INFO');
            java.lang.System.setProperty('javax.xml.transform.TransformerFactory', 'com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl');
            %
    end                             
%-------------------------------------------------------------------------%
    function handles = setup_menu(obj,handles)
            % + File menu
            menu_file = uimenu( obj.window, 'Label', 'File');
            handles. m1 = uimenu( menu_file, 'Label','Set src directory', 'Callback', @obj.onSetSrcDirectory);
            handles. m2 = uimenu( menu_file, 'Label','Set src directory list', 'Callback', @obj.onSetSrcDirectoryList); % TO DO
            handles. m3 = uimenu( menu_file, 'Label','Set dst directory', 'Callback', @obj.onSetDstDirectory,'Separator','on'); % TO DO
            handles. m4 = uimenu( menu_file, 'Label', 'Exit', 'Callback', @obj.close_request_fcn,'Separator','on'); % TO DO
            % + Settings menu
            menu_settings = uimenu( obj.window, 'Label', 'Settings' );
            handles.m5 = uimenu( menu_settings, 'Label', 'Edit src directory list', 'Callback', @obj.onSrcListEdit );                    
        end
%-------------------------------------------------------------------------%                
    function close_request_fcn(obj,~,~)            
            %
            obj.save_settings;
            %
            handles = guidata(obj.window);
            %
            % Make sure we clean up all the left over classes
            names = fieldnames(handles);
                      
            for i=1:length(names)
                % Check the field is actually a handle and isn't the window
                % which we need to close right at the end
                if ~strcmp(names{i},'window') && all(ishandle(handles.(names{i})))
                    delete(handles.(names{i}));
                end
            end
            %            
            delete(handles.window);   
            %
            % still not sure.. but something like this
            clear('handles');
            clear('i');
            clear('names');                                        
            clear('obj');
            %
        end        
%-------------------------------------------------------------------------%
    function handles = setup_layout(obj, handles)
            %
            main_layout = uiextras.VBox( 'Parent', obj.window, 'Spacing', 3 );
            top_layout = uiextras.VBox( 'Parent', main_layout, 'Spacing', 3 );            
            lower_layout = uiextras.HBox( 'Parent', main_layout, 'Spacing', 3 );
            set(main_layout,'Sizes',[-3 -1]);
            %    
            display_tabpanel = uiextras.TabPanel( 'Parent', top_layout, 'TabSize', 80 );
            handles.display_tabpanel = display_tabpanel;                                 
            %
            layout1 = uiextras.VBox( 'Parent', display_tabpanel, 'Spacing', 3 );    
            handles.panel1 = uipanel( 'Parent', layout1 );
            %
%             layout2 = uiextras.VBox( 'Parent', display_tabpanel, 'Spacing', 3 );    
%             handles.panel2 = uipanel( 'Parent', layout2 );
            %
            % set(display_tabpanel, 'TabNames', {'General','Annotations'});
            set(display_tabpanel, 'TabNames', {' '});
            set(display_tabpanel, 'SelectedChild', 1);        
            %
            % lower..
            lower_left_layout = uiextras.VButtonBox( 'Parent', lower_layout );
            
            handles.on_Set_Src_Dir_button = uicontrol( 'Parent', lower_left_layout, 'String', 'Set src directory','Callback', @obj.onSetSrcDirectory );
            handles.on_Set_Src_Dir_List_button = uicontrol( 'Parent', lower_left_layout, 'String', 'Set src directory list ','Callback', @obj.onSetSrcDirectoryList );            
            handles.on_Set_Dst_Dir_List_button = uicontrol( 'Parent', lower_left_layout, 'String', 'Set dst directiory','Callback', @obj.onSetDstDirectory ); 

            lower_right_layout = uiextras.Grid( 'Parent', lower_layout, 'Spacing', 3, 'Padding', 3, 'RowSizes',-1,'ColumnSizes',-1  );                        
            set( lower_left_layout, 'ButtonSize', [110 20], 'Spacing', 5 );   
            set(lower_layout,'Sizes',[-1 -4]);            
            % lower..
            %            
            % "General" panel            
            general_layout = uiextras.Grid( 'Parent', handles.panel1, 'Spacing', 10, 'Padding', 16, 'RowSizes',-1,'ColumnSizes',-1  );
                                    
            %
            uiextras.Empty( 'Parent', general_layout );
            uiextras.Empty( 'Parent', general_layout );
            uiextras.Empty( 'Parent', general_layout );    
            uiextras.Empty( 'Parent', general_layout );    
            uiextras.Empty( 'Parent', general_layout );                
            %
            uiextras.Empty( 'Parent', general_layout );            
            uiextras.Empty( 'Parent', general_layout );                         
            handles.onGo_button = uicontrol( 'Style', 'pushbutton', 'String', 'Go','HorizontalAlignment', 'right', 'Parent', general_layout,'Callback', @obj.onGo);
            uiextras.Empty( 'Parent', general_layout );    
            handles.SPW_text = uicontrol( 'Style', 'text', 'String', 'Gated FLIM SPW','HorizontalAlignment', 'right', 'Parent', general_layout);
            %
            uiextras.Empty( 'Parent', general_layout );
            uiextras.Empty( 'Parent', general_layout );
            uiextras.Empty( 'Parent', general_layout );
            uiextras.Empty( 'Parent', general_layout );    
            handles.SPW_check = uicontrol( 'Style', 'checkbox',  'Parent', general_layout); % TO DO - correct            
            %            
            
            uicontrol( 'Style', 'text', 'String', 'Modulo ',       'HorizontalAlignment', 'right', 'Parent', general_layout );
            uicontrol( 'Style', 'text', 'String', 'Modulo Variable ', 'HorizontalAlignment', 'right', 'Parent', general_layout );
            uicontrol( 'Style', 'text', 'String', 'Modulo Units ',    'HorizontalAlignment', 'right', 'Parent', general_layout );
            uicontrol( 'Style', 'text', 'String', 'FLIM mode ',    'HorizontalAlignment', 'right', 'Parent', general_layout );
            uicontrol( 'Style', 'text', 'String', 'Extension ',    'HorizontalAlignment', 'right', 'Parent', general_layout );
            %
            handles.Modulo_popupmenu = uicontrol( 'Style', 'popupmenu', 'String', obj.Modulo_popupmenu_str, 'Parent', general_layout,'Callback', @obj.onModuloSet ); 
            handles.Variable_popupmenu = uicontrol( 'Style', 'popupmenu', 'String', obj.Variable_popupmenu_str, 'Parent', general_layout,'Callback', @obj.onVariableSet );    
            handles.Units_popupmenu = uicontrol( 'Style', 'popupmenu', 'String',obj.Units_popupmenu_str, 'Parent', general_layout,'Callback', @obj.onUnitsSet );    
            handles.FLIM_mode_popupmenu = uicontrol( 'Style', 'popupmenu', 'String',obj.FLIM_mode_popupmenu_str, 'Parent', general_layout,'Callback', @obj.onFLIM_modeSet );    
            handles.Extension_popupmenu = uicontrol( 'Style', 'popupmenu', 'String',obj.Extension_popupmenu_str, 'Parent', general_layout,'Callback', @obj.onExtensionSet );            
            %            
             set(general_layout,'RowSizes',[22 22 22 22 22]);
             set(general_layout,'ColumnSizes',[50 100 50 170 120]);
            %
            % lower right
            handles.Src_name = uicontrol( 'Style', 'text', 'String', '???', 'HorizontalAlignment', 'center', 'Parent', lower_right_layout,'BackgroundColor','white' );
            handles.SrcList_name = uicontrol( 'Style', 'text', 'String', '???', 'HorizontalAlignment', 'center', 'Parent', lower_right_layout,'BackgroundColor','white' );
            handles.Dst_name = uicontrol( 'Style', 'text', 'String', '???', 'HorizontalAlignment', 'center', 'Parent', lower_right_layout,'BackgroundColor','white' );
            set(lower_right_layout,'RowSizes',[-1 -1 -1]);
            set(lower_right_layout,'ColumnSizes',-1);
            %
        end % setup_layout        
%-------------------------------------------------------------------------%        
    function updateInterface(obj,~,~)
            %
             if ~isempty(obj.Src)
                 set( obj.gui.Src_name,'String',char(obj.Src) );
             end;
             if ~isempty(obj.Dst)
                 set( obj.gui.Dst_name,'String',char(obj.Dst) );
             end;
             if ~isempty(obj.SrcList)
                 set( obj.gui.SrcList_name,'String',char(obj.SrcList) );
             end;
        end
%-------------------------------------------------------------------------%        
    function onGo(obj,~,~)
            
            SPW_mode = get(obj.gui.SPW_check,'Value');
                             
            if isdir(obj.Src) && isdir(obj.Dst) % single dir
                 
                 if SPW_mode
                    obj.save_as_SPW;
                 else
                    obj.save_as_1d_FOV_or_FOVs;                    
                 end
                 
            elseif isdir(obj.Dst) && exist(obj.SrcList,'file')  % BATCH
                
                try [~,srclist,~] = xlsread(obj.SrcList); 
                catch err, 
                    errordlg(err.message), 
                    obj.SrcList = '???';
                    obj.updateInterface;                    
                    return, 
                end;
           
                [numdir, numsettings] = size(srclist);
                dirs = srclist(:,1);
                % check if all directories are OK      
                for d=1:numel(dirs)                    
                    if ~isdir(char(dirs{d}))
                        errordlg(['Directory list has not been set: ' char(dirs{d}) ' not a directory']); 
                        return;
                    end
                end     
                %
                hw = waitbar(0, 'creating OME.tiffs, please wait...');
                for d = 1:numdir                    
                    obj.Src = char(dirs{d}); 
                    %
%                     % other settings
%                     if numsettings > 1
%                         obj.Modulo = char(modulos{d});
%                         obj.Variable = char(variables{d});
%                         obj.Units = char(unitss{d});
%                         obj.FLIM_mode = char(flim_modes{d});                                                    
%                         obj.Extension = char(extensions{d});
%                         %
%                         obj.set_gui_string_item('Modulo_popupmenu',obj.Modulo);
%                         obj.set_gui_string_item('Variable_popupmenu',obj.Variable);
%                         obj.set_gui_string_item('Units_popupmenu',obj.Units);
%                         obj.set_gui_string_item('FLIM_mode_popupmenu',obj.FLIM_mode);
%                         obj.set_gui_string_item('Extension_popupmenu',obj.Extension);                            
%                     end                    
                    %
                    obj.updateInterface;
                    %
                    if SPW_mode
                        obj.save_as_SPW;
                    else
                        obj.save_as_1d_FOV_or_FOVs;                    
                    end                    
                    %
                    waitbar(d/numel(dirs),hw);
                    drawnow; 
                end %for d = 1:numdir                    
                delete(hw);drawnow;
                obj.Src = '???';
                obj.updateInterface;
            else
                 errordlg('wrong Src/Dst setups'), return;
            end            
        end        
%-------------------------------------------------------------------------%                    
    function onSetSrcDirectory(obj,~,~)
            obj.Src = uigetdir(obj.DefaultDataDirectory,'Select the folder containing the data');     
            %
            if 0 ~= obj.Src            
                obj.DefaultDataDirectory = obj.Src;
                obj.SrcList = '???';
                obj.updateInterface;
            end        
        end
%-------------------------------------------------------------------------%                    
    function onSetSrcDirectoryList(obj,~,~)
           [file,path] = uigetfile('*.xlsx;*.xls','Select an Excel file containing list of data directories',obj.DefaultDataDirectory);            
           if 0 ~= file
                obj.SrcList = [path file];
                obj.Src = '???';
                obj.DefaultDataDirectory = obj.SrcList;
                obj.updateInterface;                
           end
        end    
%-------------------------------------------------------------------------%
    function onSetDstDirectory(obj,~,~)
            obj.Dst = uigetdir(obj.DefaultDataDirectory,'Select the OME.tiff folder ');     
            %
            if 0 ~= obj.Dst            
                obj.DefaultDataDirectory = obj.Dst;
                obj.updateInterface;
            end        
        end         
%-------------------------------------------------------------------------%
    function set_gui_string_item(obj,handle,value)             
             s = obj.([(handle) '_str']);
             set(obj.gui.(handle),'Value',find(cellfun(@strcmp,s,repmat({value},1,numel(s)))==1));
        end
%-------------------------------------------------------------------------%  
    function save_settings(obj,~,~)        
            ic_converter_settings = [];
            ic_converter_settings.DefaultDataDirectory = obj.DefaultDataDirectory;        
            ic_converter_settings.Modulo = obj.Modulo;                             
            ic_converter_settings.Variable = obj.Variable;
            ic_converter_settings.Units = obj.Units;        
            ic_converter_settings.FLIM_mode = obj.FLIM_mode;
            ic_converter_settings.Extension = obj.Extension;            
            ic_converter_settings.SPW_mode = get(obj.gui.SPW_check,'Value');
            ic_converter_settings.excel_path = obj.excel_path;
            xml_write('ic_converter_settings.xml', ic_converter_settings);
        end % save_settings
%-------------------------------------------------------------------------%          
    function onModuloSet(obj,~,~)
              obj.on_popupmenu_set('Modulo');
        end
%-------------------------------------------------------------------------%          
    function onVariableSet(obj,~,~)
              obj.on_popupmenu_set('Variable');
        end
%-------------------------------------------------------------------------%          
    function onUnitsSet(obj,~,~)
              obj.on_popupmenu_set('Units');
        end
%-------------------------------------------------------------------------%          
    function onFLIM_modeSet(obj,~,~)
              obj.on_popupmenu_set('FLIM_mode');
        end
%-------------------------------------------------------------------------%          
    function onExtensionSet(obj,~,~)
              obj.on_popupmenu_set('Extension');
        end        
%-------------------------------------------------------------------------%          
    function on_popupmenu_set(obj,pName,~)            
            value = get(obj.gui.([pName '_popupmenu']),'Value');
            obj.(pName) = obj.([pName '_popupmenu_str'])(value);            
        end
%-------------------------------------------------------------------------%                                                    
    function EnableEverythingExceptCancel(obj,mode,~)      
                    set(obj.gui.Modulo_popupmenu,'Enable',mode);
                  set(obj.gui.Variable_popupmenu,'Enable',mode);
                     set(obj.gui.Units_popupmenu,'Enable',mode);
                 set(obj.gui.FLIM_mode_popupmenu,'Enable',mode);
                 set(obj.gui.Extension_popupmenu,'Enable',mode);
                 
                            set(obj.gui.SPW_text,'Enable',mode);
                            set(obj.gui.SPW_check,'Enable',mode);

                            set(obj.gui.Src_name,'Enable',mode);
                            set(obj.gui.SrcList_name,'Enable',mode);
                            set(obj.gui.Dst_name,'Enable',mode);                            
                                  set(obj.gui.m1,'Enable',mode);
                                  set(obj.gui.m2,'Enable',mode);
                                  set(obj.gui.m3,'Enable',mode);
                                  set(obj.gui.m4,'Enable',mode);
                                  set(obj.gui.m5,'Enable',mode);
                                  set(obj.gui.m6,'Enable',mode);
                                  set(obj.gui.m7,'Enable',mode);
                                  set(obj.gui.m8,'Enable',mode);
                                  set(obj.gui.m9,'Enable',mode);
                                  set(obj.gui.m10,'Enable',mode);
                                  set(obj.gui.m11,'Enable',mode);                                  
                                  set(obj.gui.m12,'Enable',mode);                                                                    
            set(obj.gui.onCheckOut_button,'Enable',mode);
            set(obj.gui.onGo_button,'Enable',mode); 
            set(obj.on_Set_Src_Dir_button,'Enable',mode); 
            set(obj.on_Set_Src_Dir_List_button,'Enable',mode); 
            set(obj.on_Set_Dst_Dir_List_button,'Enable',mode);                         
            %
    end
%-------------------------------------------------------------------------%
    function save_as_1d_FOV_or_FOVs(obj,~,~)
                                
            if isempty(obj.Src) || isempty(obj.Dst), errordlg('Source/Destination have not been set up - can not continue'), return, end;

            dimension = [];
            switch char(obj.Modulo)
                case 'ModuloAlongZ'
                  dimension = 'ModuloAlongZ';
                case 'ModuloAlongC'
                  dimension = 'ModuloAlongC';
                case 'ModuloAlongT'                
                  dimension = 'ModuloAlongT';                
            end
                        
            if isempty(dimension), errordlg('dimension not specified, can not continue'), return, end;

            files = dir([char(obj.Src) filesep '*.' char(obj.Extension)]);
            num_files = length(files);
            
            save_mode = [];
            
            if 0 ~= num_files
                names_list = cell(1,num_files);
                for k = 1:num_files
                    names_list{k} = char(files(k).name);
                end
                save_mode = 'single dir';
            else                
                % analyze if directory contains stack directories                
                dir_names = [];
                z = 0;
                FLSRAW = dir(char(obj.Src));                
                for k = 1:numel(FLSRAW)
                    name_k = char(FLSRAW(k).name);
                    if FLSRAW(k).isdir && ~strcmp(name_k,'.') && ~strcmp(name_k,'..')                        
                        z = z + 1;
                        dir_names{z} = name_k;
                    end
                end
                %
                nonemptydir_names = [];
                z = 0;
                for k=1:numel(dir_names)
                    files_k = dir([char(obj.Src) filesep dir_names{k} filesep '*.' char(obj.Extension)]);
                    if 0 ~= numel(files_k)
                        z = z + 1;
                        nonemptydir_names{z} = dir_names{k};
                    end
                end
                %
                if ~isempty(nonemptydir_names), 
                    save_mode = 'multiple dirs'; 
                end;
            end
                
            if isempty(save_mode), errordlg('no image files found - can not continue'), return, end;
            
            savedir = char(obj.Dst);            
                
            if strcmp(save_mode,'single dir')
                %
                names_list = sort_nat(names_list);
                %                
                if strcmp(obj.Extension,'txt')                    
                    obj.save_single_pixel(names_list,char(obj.Dst));
                else
                    strings1 = strrep(obj.Src,filesep,'/'); 
                    strng = split('/',strings1);
                    imageName = char(strng(length(strng)));    
                    ometiffilename = [savedir filesep imageName '.OME.tiff'];                
                    save_stack_as_OMEtiff(obj.Src, names_list, char(obj.Extension), dimension, obj.FLIM_mode, ometiffilename);
                end                
                %
            elseif strcmp(save_mode,'multiple dirs')
                %
                hw = waitbar(0, 'transferring data, please wait...');                
                for k=1:numel(nonemptydir_names)
                    files_k = dir([char(obj.Src) filesep nonemptydir_names{k} filesep '*.' char(obj.Extension)]);
                        num_files_k = numel(files_k);
                        names_list_k = cell(1,num_files_k);
                        for m = 1:num_files_k
                            names_list_k{m} = char(files_k(m).name);
                        end
                        names_list_k = sort_nat(names_list_k);
                        ometiffilename = [savedir filesep nonemptydir_names{k} '.OME.tiff'];                                  
                        %
                        if strcmp(obj.Extension,'txt')
                            obj.save_single_pixel(nonemptydir_names,char(obj.Dst));
                        else    
                            save_stack_as_OMEtiff([char(obj.Src) filesep nonemptydir_names{k}], names_list_k, char(obj.Extension), dimension, obj.FLIM_mode, ometiffilename);
                        end
                        %                        
                    waitbar(k/numel(nonemptydir_names),hw);
                    drawnow
                end
                delete(hw);
                drawnow;
                %
            end                                                
    end
%-------------------------------------------------------------------------%    
    function save_as_SPW(obj,~,~)    

            %                
            if isempty(obj.Src), errordlg('Source has not been set up - can not continue'), return, end;            
            %            
            if ~strcmp(char(obj.Modulo),'ModuloAlongT'), errordlg('ModuloAlongT expected, please set up!'), return, end;
            %
            savedir = char(obj.Dst);
            %
            strings1 = strrep(obj.Src,filesep,'/'); 
            strng = split('/',strings1);
            imageName = char(strng(length(strng)));
            ometiffilename = [savedir filesep imageName '.ome.tiff'];
                                    
            folder = obj.Src;

            format = 'format_old';
            try PlateSetups = parse_WP_format(folder); catch err, errordlg(err.message), return, end;
            %
            if isempty(PlateSetups)            
                try PlateSetups = parse_MultiChannel_WP_format(folder); catch err, errordlg(err.message), return, end;                                
                format = 'format_multichannel';
            end;
            
            if true(strcmp(format,'format_old'))
                                                                          
             row_max = max(PlateSetups.rows)+1;
             col_max = max(PlateSetups.cols)+1;
             nFovInWell = zeros(row_max,col_max);
             %            
             nFOV = length(PlateSetups.rows);
             for k=1:nFOV
                 row = PlateSetups.rows(k);
                 col = PlateSetups.cols(k);
                 nFovInWell(row+1,col+1) = nFovInWell(row+1,col+1) + 1;
             end                          
             %
             % r = loci.formats.ChannelFiller();
             % r = loci.formats.ChannelSeparator(r);
             % OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
             % r.setMetadataStore(OMEXMLService.createOMEXMLMetadata());
             %
             SPWWriter = [];
             getBytes = [];
             %
             hw = waitbar(0, 'Upoading Plate...');
             for f = 1 : nFOV
                 subdir = PlateSetups.names{f};
                 subPath = [folder filesep subdir];
                 %
                 files = dir([subPath filesep '*.' PlateSetups.extension]);
                 num_files = length(files);
                 if 0==num_files
                     errordlg('No suitable files in the directory');
                     return;
                 end;
                 %
                 file_names = cell(1,num_files);
                    for i=1:num_files
                        file_names{i} = files(i).name;
                    end
                 file_names = sort_nat(file_names);                 
                                  
                 if isempty( SPWWriter ) % then init SPWWriter
                     delayList = cell(1,num_files);
                     for i = 1 : num_files                
                         fnamestruct = parse_DIFN_format1(file_names{i});
                         delayList{i} = fnamestruct.delaystr; % delay [ps] in string format
                     end 
                     %
                     % try ExposureTimes                     
                     ExposureTimes = zeros(1,num_files);
                     try
                         for i = 1 : num_files                
                             fname  = file_names{i};
                             strs = strsplit(fname,' ');
                             str1 = strs(1);
                             str2 = strsplit(char(str1),'_');
                             if strcmp(str2(1),'INT')
                                ExposureTimes(i) = str2double(char(str2(2)))/1000; %millisec to seconds
                             end
                         end 
                     catch err, errordlg(err.message), end;
                     %                     
                     sizet = num_files;                     
                     % r.setId([subPath filesep file_names{1}]);                                                
                     % sizeX = r.getSizeX();
                     % sizeY = r.getSizeY();                     
                     %                     
                     try I = imread([subPath filesep file_names{1}],PlateSetups.extension); catch err, msgbox(err.mesasge), return, end;
                     I = I';
                     sizeX = size(I,1);
                     sizeY = size(I,2);
                     %                     
                     switch class(I)
                        case {'int8', 'uint8'}
                            getBytes = @(x) x(:);
                        case {'uint16','int16'}
                            getBytes = @(x) loci.common.DataTools.shortsToBytes(x(:), 0);
                        case {'uint32','int32'}
                            getBytes = @(x) loci.common.DataTools.intsToBytes(x(:), 0);
                        case {'single'}
                            getBytes = @(x) loci.common.DataTools.floatsToBytes(x(:), 0);
                        case 'double'
                            getBytes = @(x) loci.common.DataTools.doublesToBytes(x(:), 0);
                     end
                     %                                                                                                                              
                     SPWWriter = SPW.FileWriteSPW(ometiffilename);
                     %
                     if 0 ~= min(ExposureTimes)                     
                        ok = SPWWriter.init(nFovInWell, sizeX, sizeY, sizet, toJavaList(delayList,'java.lang.String'),ExposureTimes);
                     else
                        ok = SPWWriter.init(nFovInWell, sizeX, sizeY, sizet, toJavaList(delayList,'java.lang.String'));                         
                     end                                                               
                     if ~ok, errordlg('oops can not initialize FileWriteSPW'), return, end;
                 end % init SPWWriter
                 %
                 for i = 1 : num_files                                     
                    fname = [subPath filesep file_names{i}];                    
                        % r.setId(fname);
                        % plane = r.openBytes(0);
                        % SPWWriter.export(plane, f-1, i-1);                                                
                    I = imread(fname,PlateSetups.extension);
                    SPWWriter.export(getBytes(I'), f-1, i-1);                                                                               
                 end                                      
                 waitbar(f/nFOV,hw); drawnow;                                 
             end             
             delete(hw); drawnow;
             
             SPWWriter.cleanup();
                                       
            elseif true(strcmp(format,'format_multichannel'))
                %
                % TO DO
                %
            end
    end    
%-------------------------------------------------------------------------%
    function save_single_pixel(obj,file_names,output_dir)
        
            %  
            if strcmp(obj.Modulo,'none') || ~strcmp(obj.Extension,'txt')        
                errordlg('Incompatible settings'),
                return,
            end;
            %
            if strcmp(obj.Variable,'lifetime') && ~strcmp(obj.FLIM_mode,'none') && ... 
                    ~strcmp(obj.FLIM_mode,'TCSPC') && ~ strcmp(obj.FLIM_mode,'Time Gated')...
                    && ( strcmp(obj.Units,'ps') || strcmp(obj.Units,'ns') )   
                % this is FLIM..
                if strcmp(obj.FLIM_mode,'TCSPC non-imaging')
                    type_description = 'TCSPC';
                else
                    type_description = 'Gated';
                end
            else % still using Modulo..
                type_description = 'Spectrum';
            end
            %
            num_files = length(file_names);            
                           
            hw = waitbar(0, 'Upoading images...');                
            for k=1:num_files
                
                waitbar(k/num_files,hw); drawnow;             
            
                full_filename = [obj.Src filesep char(file_names{k})];
                
                try
                    D = load(lower(full_filename),'ascii');
                catch err, errordlg(err.message), return, 
                end;
                %
                [~,n_ch1] = size(D);
                chnls = (2:n_ch1)-1;    
                [delays,im_data,~] = load_flim_file(lower(full_filename),chnls);
                %
                [sizeT,sizeC] = size(im_data);
                %
                sizeX = 1;
                sizeY = 1;
                sizeZ = 1;
                %
                data = zeros(sizeX,sizeY,sizeZ,sizeC,sizeT,class(im_data));
                %
                for c = 1 : sizeC,
                    data(1,1,1,c,:) = im_data(:,c);
                end
                %                                               
                metadata = createMinimalOMEXMLMetadata(data);

                modlo = loci.formats.CoreMetadata();        

                % Set channels ID and samples per pixel
                toInt = @(x) ome.xml.model.primitives.PositiveInteger(java.lang.Integer(x));
                for i = 1: sizeC
                    metadata.setChannelID(['Channel:0:' num2str(i-1)], 0, i-1);
                    metadata.setChannelSamplesPerPixel(toInt(1), 0, i-1);
                end

                if strcmp(type_description,'Gated')
                        modlo.moduloT.type = loci.formats.FormatTools.LIFETIME;
                        modlo.moduloT.unit = obj.Units;
                        modlo.moduloT.typeDescription = type_description;
                        modlo.moduloT.labels = javaArray('java.lang.String',length(delays));
                        for i=1:length(delays)
                            modlo.moduloT.labels(i)= java.lang.String(num2str(delays(i)));
                        end                    
                elseif strcmp(type_description,'TCSPC')
                        modlo.moduloT.type = loci.formats.FormatTools.LIFETIME;
                        modlo.moduloT.unit = obj.Units;
                        modlo.moduloT.typeDescription = type_description;
                        modlo.moduloT.start = delays(1);
                        modlo.moduloT.end = delays(end);
                        modlo.moduloT.step = (delays(end) - delays(1))./(length(delays)-1);
                elseif strcmp(type_description,'Spectrum')
                        % ?
                end

                OMEXMLService = loci.formats.services.OMEXMLServiceImpl();

                OMEXMLService.addModuloAlong(metadata,modlo,0);

                cutfname = [output_dir filesep char(file_names{k})];
                L = length(cutfname);
                cutfname = cutfname(1:L-3);
                full_output_filename = [cutfname 'OME.tiff'];            
                bfsave(data, full_output_filename, 'metadata', metadata);
            
            end % for k = num_files     
            delete(hw); drawnow;
        end      
%-------------------------------------------------------------------------%
    function onSrcListEdit(obj,~,~)

            if isempty(obj.SrcList) || strcmp(char(obj.SrcList),'???'), 
                errordlg('Source directory list was not set up - can not edit'), 
                return, 
            end;                
                        
            prevdir = pwd;            
            
            try
                if isempty(obj.excel_path)
                    cd('c:\');
                    [~,b] = dos('dir /s /b excel.exe');
                    filenames = textscan(b,'%s','delimiter',char(10));
                    s = char(filenames{1});
                    s = s(1,:);
                    s = strsplit(s,'EXCEL.EXE');
                    obj.excel_path = s{1};
                end                
                cd(obj.excel_path);
                %
                dos(['excel ' char(obj.SrcList)]);
            catch
            end
            
            cd(prevdir);            
        end
        
    end % methods
    %    
end
