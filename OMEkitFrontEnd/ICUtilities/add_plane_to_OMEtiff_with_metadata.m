function add_plane_to_OMEtiff_with_metadata(I, index, final_index, folder, ometiffilename, ... 
    physszX, physszY, zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step)

global writer;
global getBytes;
global hw;

if 1 == index % make all setups

        addpath_OPTkit;

        [sizeX, sizeY] = size(I);
        sizeZ = final_index;
        sizeC = 1;
        sizeT = 1;        

        % verify that enough memory is allocated
        bfCheckJavaMemory();
        % Check for required jars in the Java path
        bfCheckJavaPath();

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
if nargin > 5
    metadata.setPixelsPhysicalSizeX(ome.xml.model.primitives.PositiveFloat(java.lang.Double(physszX)),0);
    metadata.setPixelsPhysicalSizeY(ome.xml.model.primitives.PositiveFloat(java.lang.Double(physszY)),0);
end

if nargin > 7
    modlo = loci.formats.CoreMetadata();        
    %
    % loci.formats.FormatTools.ROTATION;
    % zdim_label, zdim_unit, zdim_typeDescription, zdim_start, zdim_end, zdim_step)
    modlo.moduloZ.type = zdim_label;
    modlo.moduloZ.unit = zdim_unit;
    modlo.moduloZ.typeDescription = zdim_typeDescription;
end

if nargin == 13 % start end step
    modlo.moduloZ.start = zdim_start;
    modlo.moduloZ.end = zdim_end;
    modlo.moduloZ.step = zdim_step;
elseif nargin == 11 && length(zdim_start) > 1 % labels - array of numbers...
    labels = zdim_start;
    modlo.moduloZ.labels = javaArray('java.lang.String',length(labels));
    for i=1:length(labels)
        modlo.moduloZ.labels(i)= java.lang.String(num2str(labels(i)));
    end                                                      
end

if exist('modlo','var') OMEXMLService.addModuloAlong(metadata, modlo, 0); end;
%%%%%%%%%%%%%%%%%%% set up Modulo XML description metadata if present - ends        

% XMLAnnotaiton arrangement
% if only modulo present it goes with 0
% if description is present, it goes with 0
% then if modulo and description are present modulo goes with with 0 then
% description with 1

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
        
        hw = waitbar(0, 'Loading images...');
end        

writer.saveBytes(index-1, getBytes(I));
waitbar(index/final_index,hw); drawnow;    
        
if index == final_index
    delete(hw); 
    drawnow;
    writer.close();
    
    %xmlValidate = loci.formats.tools.XMLValidate();
    %comment = loci.formats.tiff.TiffParser(ometiffilename).getComment()
    %xmlValidate.process(ometiffilename, java.io.BufferedReader(java.io.StringReader(comment)));    
end;
               
end

        