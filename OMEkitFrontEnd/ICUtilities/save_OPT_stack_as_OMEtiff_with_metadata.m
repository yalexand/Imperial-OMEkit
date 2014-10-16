function speed = save_OPT_stack_as_OMEtiff_with_metadata(folder, ometiffilename, ... 
    physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step)
%{
- single channel
- tif extension
- images in the "folder" directory are sorted in "natural" order
- in the OME-tiff, images are set along Z direction
- LZW compression
- xml file specifying custom metadata ("description") is in "folder" directory, or one level up if former not present
%}
addpath_OMEkit;

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
            
            num_files = numel(file_names);
            %
            sizeC = 1;
            sizeZ = num_files;
            sizeT = 1;            

            try I = imread([folder filesep file_names{1}],extension); catch err, msgbox(err.mesasge), return, end;
            I = I';
            sizeX = size(I,1);
            sizeY = size(I,2);
            %

        % verify that enough memory is allocated
        bfCheckJavaMemory();
        % Check for required jars in the Java path
        bfCheckJavaPath();
        
        % ini logging
        loci.common.DebugTools.enableLogging('INFO');
        java.lang.System.setProperty('javax.xml.transform.TransformerFactory', 'com.sun.org.apache.xalan.internal.xsltc.trax.TransformerFactoryImpl');
        
        % Create metadata
        toInt = @(x) ome.xml.model.primitives.PositiveInteger(java.lang.Integer(x));
        OMEXMLService = loci.formats.services.OMEXMLServiceImpl();
        metadata = OMEXMLService.createOMEXMLMetadata();
        metadata.createRoot();
        metadata.setImageID('Image:0', 0);
        metadata.setPixelsID('Pixels:0', 0);
        metadata.setPixelsBinDataBigEndian(java.lang.Boolean.TRUE, 0, 0);

        % Set dimension order
        dimensionOrderEnumHandler = ome.xml.model.enums.handlers.DimensionOrderEnumHandler();
        dimensionOrder = dimensionOrderEnumHandler.getEnumeration('XYZCT');
        metadata.setPixelsDimensionOrder(dimensionOrder, 0);

        % Set pixels type
        pixelTypeEnumHandler = ome.xml.model.enums.handlers.PixelTypeEnumHandler();
        if strcmp(class(I), 'single')
            pixelsType = pixelTypeEnumHandler.getEnumeration('float');
        else
            pixelsType = pixelTypeEnumHandler.getEnumeration(class(I));
        end

        metadata.setPixelsType(pixelsType, 0);

        metadata.setPixelsSizeX(toInt(sizeX), 0);
        metadata.setPixelsSizeY(toInt(sizeY), 0);
        metadata.setPixelsSizeZ(toInt(sizeZ), 0);
        metadata.setPixelsSizeC(toInt(sizeC), 0);
        metadata.setPixelsSizeT(toInt(sizeT), 0);
                
        % Set channels ID and samples per pixel
        for i = 1: sizeC
            metadata.setChannelID(['Channel:0:' num2str(i-1)], 0, i-1);
            metadata.setChannelSamplesPerPixel(toInt(1), 0, i-1);
        end
               
%%%%%%%%%%%%%%%%%%% set up Modulo XML description metadata if present - starts
if nargin > 2
    metadata.setPixelsPhysicalSizeX(ome.xml.model.primitives.PositiveFloat(java.lang.Double(physszX)),0);
    metadata.setPixelsPhysicalSizeY(ome.xml.model.primitives.PositiveFloat(java.lang.Double(physszY)),0);
end

if nargin > 4
    modlo = loci.formats.CoreMetadata();        
    %
    % loci.formats.FormatTools.ROTATION;
    % zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step)
    modlo.moduloZ.type = zdim_label;
    modlo.moduloZ.unit = zdim_unit;
    modlo.moduloZ.typeDescription = zdim_typeDescription;
end

if nargin == 10 % start end step
    modlo.moduloZ.start = zdim_start;
    modlo.moduloZ.end = zdim_end;
    modlo.moduloZ.step = zdim_step;
elseif nargin == 8 && length(zdim_start) > 1 % labels - array of numbers...
    labels = zdim_start;
    modlo.moduloZ.labels = javaArray('java.lang.String',length(labels));
    for i=1:length(labels)
        modlo.moduloZ.labels(i)= java.lang.String(num2str(labels(i)));
    end                                                      
end

if exist('modlo','var') OMEXMLService.addModuloAlong(metadata, modlo, 0); end;
%%%%%%%%%%%%%%%%%%% set up Modulo XML description metadata if present - ends

        % DESCRIPTION - one needs to find xml file if there... and so on
        try
            n_anno = 0;
            if exist('modlo','var'), n_anno = n_anno + 1; end;
            
            description = [];
            xmlfilename = [];
            xmlfilenames = dir([folder filesep '*.xml']);                
            if 1 == numel(xmlfilenames), xmlfilename = xmlfilenames(1).name; end;
            if ~isempty(xmlfilename)
                fid = fopen([folder filesep xmlfilename],'r');
                fgetl(fid);
                description = fscanf(fid,'%c');
                fclose(fid);
            end                        
            if ~isempty(description) % on retrieving apply OMEXMLdescription = r.getMetadataStore().getXMLAnnotationValue(0);                
                metadata.setXMLAnnotationID(['Annotation:' num2str(n_anno)],n_anno); 
                metadata.setXMLAnnotationValue(description,n_anno);
            end
            %
            % try the same, one level up
            description = []; 
            xmlfilename = [];            
            sf = strfind(folder,filesep);
            xmlfilenames = dir([folder(1:sf(length(sf))) '*.xml']);                
                if 1 == numel(xmlfilenames), xmlfilename = xmlfilenames(1).name; end;
                if ~isempty(xmlfilename)
                    fid = fopen([folder(1:sf(length(sf))) xmlfilename],'r');
                    fgetl(fid);                
                    description = fscanf(fid,'%c');
                    fclose(fid);
                end
            if ~isempty(description) 
                % on retrieving apply OMEXMLdescription = r.getMetadataStore().getXMLAnnotationValue(0);               
                n_anno = n_anno + 1;
                metadata.setXMLAnnotationID(['Annotation:' num2str(n_anno)],n_anno); 
                metadata.setXMLAnnotationValue(description,n_anno);
            end                            
            %        
        catch err
            display(err.message);
        end
        % DESCRIPTION - ends

        % Create ImageWriter
        writer = loci.formats.ImageWriter();
        writer.setWriteSequentially(true);
        writer.setMetadataRetrieve(metadata);
        writer.setCompression('LZW');
        writer.getWriter(ometiffilename).setBigTiff(true);
        writer.setId(ometiffilename);

        % Load conversion tools for saving planes
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

        % Save planes to the writer
        hw = waitbar(0, 'Loading images...');        
        nPlanes = sizeZ * sizeC * sizeT;
        acc = zeros(1,nPlanes);
        for index = 1 : nPlanes
            t0 = tic;            
            I = imread([folder filesep file_names{index}],extension);            
            I = I';
                %t0 = tic;
            writer.saveBytes(index-1, getBytes(I));
            telapsed = toc(t0);
            acc(index)=telapsed;            
        waitbar(index/nPlanes,hw); drawnow;    
        end
        delete(hw); drawnow;

        writer.close();
        
        speed = mean(acc);
% xmlValidate = loci.formats.tools.XMLValidate();
% comment = loci.formats.tiff.TiffParser(ometiffilename).getComment()
% xmlValidate.process(ometiffilename, java.io.BufferedReader(java.io.StringReader(comment)));
        
end