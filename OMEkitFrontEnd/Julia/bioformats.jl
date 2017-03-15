using JavaCall, XMLDict, ProgressMeter

try
    # init JVM wtih bioformats_package.jar on classpath
    JavaCall.init(["-ea", "-Xmx1024M", "-Djava.class.path=bioformats_package.jar"])
end

# import java classes
const JChannelFiller = @jimport loci.formats.ChannelFiller
const JChannelSeparator = @jimport loci.formats.ChannelSeparator
const JOMEXMLServiceImpl = @jimport loci.formats.services.OMEXMLServiceImpl
const JOMEXMLMetadata = @jimport loci.formats.ome.OMEXMLMetadata
const JOMEXMLService = @jimport loci.formats.services.OMEXMLService
const JMetadataStore = @jimport loci.formats.meta.MetadataStore
const JFormatReader = @jimport loci.formats.FormatReader
const JIFormatReader = @jimport loci.formats.IFormatReader
const JIObject = @jimport omero.model.IObject
const JDebugTools = @jimport loci.common.DebugTools
const JModulo = @jimport loci.formats.Modulo
const JDataTools = @jimport loci.common.DataTools
const JFormatTools = @jimport loci.formats.FormatTools

const JDimensionOrderEnumHandler = @jimport ome.xml.model.enums.handlers.DimensionOrderEnumHandler
const JPixelTypeEnumHandler = @jimport ome.xml.model.enums.handlers.PixelTypeEnumHandler

const Jenum = @jimport ome.xml.model.enums.Enumeration
const JPixelType = @jimport ome.xml.model.enums.PixelType
const JDimensionOrder = @jimport ome.xml.model.enums.DimensionOrder
const JPositiveInteger = @jimport ome.xml.model.primitives.PositiveInteger

const JImageWriter = @jimport loci.formats.ImageWriter
const JIFormatWriter = @jimport loci.formats.IFormatWriter
const JTiffWriter = @jimport loci.formats.out.TiffWriter



###########################################
#
# TODO: possibly implement via Java by using Modulo set/get functions
#
function bfGetModulo(r,dim)

  ret = []
        modlo = jcall(r, "getModulo"*dim, JModulo, ())

        anno = jcall(modlo,"toXMLAnnotation",JString,())
        xml = parse_xml(anno)

            try
              Start = parse(Float64,xml[:Start])
              End = parse(Float64,xml[:End])
              Step = parse(Float64,xml[:Step])
              #
              if End > Start
                  nsteps = round((End - Start)/Step)
                  ret = (0:nsteps)
                  ret = ret*Step
                  ret = ret + Start
              end
            end

            if isempty(ret)
             try
              labels = xml["Label"]
              ret = zeros(length(labels))
              for k=1:length(labels)
                 ret[k]=parse(Float64,labels[k])
              end
             end
            end

  return ret

end

##########################
function bfGetModuloSpec(r,dim,spec)
  "nothing"
  try
  modlo = jcall(r, "getModulo"*dim, JModulo, ())
  anno = jcall(modlo,"toXMLAnnotation",JString,())
  xml = parse_xml(anno)
      if ("Type"==spec)
        xml[:Type]
      elseif ("TypeDescription"==spec)
        xml[:TypeDescription]
      elseif ("Unit"==spec)
        xml[:Unit]
      end
  end
end

##########################
function bfGetReader(filename)

  r = JChannelFiller(())
  r = JChannelSeparator((JIFormatReader,), r)
  OMEXMLService = JOMEXMLServiceImpl(())
  meta = jcall(OMEXMLService, "createOMEXMLMetadata", JOMEXMLMetadata, ())
  jcall(r, "setMetadataStore", Void, (JMetadataStore,), meta)
  jcall(r, "setId", Void, (JString,), filename)

  return r

end

##################################
#
# TODO: implement "bfGetPlane" via Bioformats functions
# as it is now, - WORKS ONLY FOR 16 BIT BIG-ENDIAN
#
# hint:
#
# if sgn
#   object = jcall(JDataTools,"makeDataArray2D", JObject,
#                (Array{jbyte, 1}, jint, jboolean, jboolean, jint),
#                plane,bpp,fp,little,Int64(sizeY))
# else
#   object = jcall(JDataTools,"makeDataArray", JObject,
#                  (Array{jbyte, 1}, jint, jboolean, jboolean),
#                  plane,bpp,fp,little)
# end
# ...
# then use object to get XY image
#
function bfGetPlane(pixelType,bpp,fp,sgn,little,sizeX,sizeY,plane)

    arr = reinterpret(jshort,plane)

    for k=1:length(arr)
      arr[k]=bswap(arr[k])
    end

    I = reshape(float(arr),Int64(sizeX),Int64(sizeY))

end

##########################
#
# TODO: cast output to corresponding pixel type
# for now it returns Float always
#
function bfGetVolume(r)

  I = []

  # % initialize logging - THAT DOESN'T WORK BY SOME REASON
  #
  # loci.common.DebugTools.enableLogging('INFO')
  # jcall(JDebugTools, "enableLogging", Void, (JString,), "INFO")

  sizeX = jcall(r, "getSizeX", jint, ())
  sizeY = jcall(r, "getSizeY", jint, ())
  sizeZ = jcall(r, "getSizeZ", jint, ())
  sizeC = jcall(r, "getSizeC", jint, ())
  sizeT = jcall(r, "getSizeT", jint, ())

  pixelType = jcall(r, "getPixelType", jint, ())
  bpp = jcall(JFormatTools,"getBytesPerPixel",jint, (jint,), pixelType)
  fp = jcall(JFormatTools,"isFloatingPoint",jboolean, (jint,), pixelType)
  sgn = jcall(JFormatTools,"isSigned",jboolean, (jint,), pixelType)
  little = jcall(r, "isLittleEndian", jboolean, ())

  jcall(r, "setSeries", Void, (jint,), 0)

  I = zeros(sizeX,sizeY,sizeZ,sizeC,sizeT)

  numImages = jcall(r, "getImageCount", jint, ())

    for i = 1:numImages
        zct = jcall(r,"getZCTCoords", Array{jint, 1}, (jint,), (i - 1))
        z = zct[1]+1
        c = zct[2]+1
        t = zct[3]+1
        #
        arr = jcall(r, "openBytes", Array{jbyte, 1}, (jint,), i-1)
        I[:,:,z,c,t] = bfGetPlane(pixelType,bpp,fp,sgn,little,sizeX,sizeY,arr)
    end

  return I

end

############################
function createMinimalOMEXMLMetadata(I,savePixeltype::String="UInt16")

    # metadata = OMEXMLService.createOMEXMLMetadata();
  OMEXMLService = JOMEXMLServiceImpl(())
  metadata = jcall(OMEXMLService, "createOMEXMLMetadata", JOMEXMLMetadata, ())

    # metadata.createRoot();
  jcall(metadata,"createRoot",Void,())
    # metadata.setImageID('Image:0', 0);
  jcall(metadata,"setImageID",Void,(JString,jint),"Image:0",0)
    # metadata.setPixelsID('Pixels:0', 0);
  jcall(metadata,"setPixelsID",Void,(JString,jint),"Pixels:0",0)

  # Matlab: metadata.setPixelsBinDataBigEndian(java.lang.Boolean.TRUE, 0, 0);
  # TODO: fix
  # jcall(metadata,"setPixelsBinDataBigEndian",Void,(jboolean,jint,jint),jboolean(true),0,0) # ???
  # TODO: fix

  # Set dimension order
  DOEH = JDimensionOrderEnumHandler(())
  dimensionOrder = jcall(DOEH, "getEnumeration",Jenum,(JString,),"XYZCT")
  jcall(metadata,"setPixelsDimensionOrder",Void,(JDimensionOrder,jint),dimensionOrder,0)

  # Set pixel type
  PTEH = JPixelTypeEnumHandler(())
  if (savePixeltype=="UInt16")
    pixelsType = jcall(PTEH,"getEnumeration",Jenum,(JString,),"uint16")
  elseif (savePixeltype=="Float64")
    pixelsType = jcall(PTEH,"getEnumeration",Jenum,(JString,),"float")
  end
  jcall(metadata,"setPixelsType",Void,(JPixelType,jint),pixelsType, 0)

  sizeX,sizeY,sizeZ,sizeC,sizeT = size(I)

  # TODO : fix (start) - this block causes errors related to JPositiveInteger
  #
  # pi_sizeX = JPositiveInteger(Int64(sizeX))
  # pi_sizeY = JPositiveInteger(Int64(sizeY))
  # pi_sizeZ = JPositiveInteger(Int64(sizeZ))
  # pi_sizeC = JPositiveInteger(Int64(sizeC))
  # pi_sizeT = JPositiveInteger(Int64(sizeT))
  # #
  # jcall(metadata,"setPixelsSizeX",Void,(JPositiveInteger,jint),pi_sizeX,0)
  # jcall(metadata,"setPixelsSizeY",Void,(JPositiveInteger,jint),pi_sizeY,0)
  # jcall(metadata,"setPixelsSizeZ",Void,(JPositiveInteger,jint),pi_sizeZ,0)
  # jcall(metadata,"setPixelsSizeC",Void,(JPositiveInteger,jint),pi_sizeC,0)
  # jcall(metadata,"setPixelsSizeT",Void,(JPositiveInteger,jint),pi_sizeT,0)
  # #
  # # # Set channels ID and samples per pixel
  # for i = 1 : sizeC
  #   jcall(metadata,"setChannelID",Void,(JString,jint,jint),"Channel:0:",0,i-1)
  #   pi_1 = JPositiveInteger(Int64(1))
  #   jcall(metadata,"setChannelSamplesPerPixel",Void,(JPositiveInteger,jint,jint),pi_1,0,i-1)
  # end
  #
  # TODO : fix (end)

  return metadata

end

############################
#
# to open file and save it using "bfsaveOMEtiff":
# id = "..\\TestData\\fluor.OME.tiff"
# r = bfGetReader(id);
# I = bfGetVolume(r)
# jcall(r, "close", Void, ())
# U = Array{UInt16}(size(I)) # not sure how to convert data to UInt16, so empty
# fill(U,0)
# bfsaveOMEtiff(U,"..\\result.OME.tiff",[],"UInt16","LZW",true)
#
function bfsaveOMEtiff(I,output_fullfilename::String,
                  metadata,
                  savePixeltype="UInt16",
                  compression::String="LZW",
                  BigTiff::Bool=true)

      if isempty(metadata)
        metadata = createMinimalOMEXMLMetadata(I,savePixeltype)
      end

      # % Create ImageWriter
        # writer = loci.formats.ImageWriter();
      writer = JTiffWriter(())

        # writer.setWriteSequentially(true);
      jcall(writer,"setWriteSequentially",Void,(jboolean,),true)

      # Matlab: writer.setMetadataRetrieve(metadata);
      # TODO: fix
      # jcall(writer,"setMetadataRetrieve",Void,(JOMEXMLMetadata,),metadata)
      # TODO: fix

      if !isempty(compression)
           # writer.setCompression(ip.Results.Compression)
           try
             jcall(writer,"setCompression",Void,(JString,),compression)
           end
      end

      if BigTiff
          jcall(writer,"setBigTiff",Void,(jboolean,),BigTiff)
      end

        # writer.setId(outputPath);
      jcall(writer,"setId",Void,(JString,),output_fullfilename)

      # TODO: fix
        # pi_sizeZ = jcall(metadata,"getPixelsSizeZ",JPositiveInteger,(jint,),0)
        # sizeZ = jall(pi_sizeZ,"getValue",jint,())
      # ... the same for C,T
      # TODO: fix

      little = false # little endian?
      sizeX,sizeY,sizeZ,sizeC,sizeT = size(I)
      nPlanes = sizeZ*sizeC*sizeT
      p = Progress(nPlanes, "saving the file..")
      for index = 1 : nPlanes
           i, j, k = ind2sub((sizeZ,sizeC,sizeT),index);
           plane = I[:, :, i, j, k]';
           #
           if ("UInt16"==savePixeltype)
             # TODO : fix
             # bytes = jcall(JDataTools,"shortsToBytes",Array{jbyte,1},(jshort,jboolean),plane,little)
             # TODO : fix
             #
             # substitute this dummy array - only here because "shortsToBytes" not working
             bytes = Array{jbyte,1}(2*sizeX*sizeY)
             #
             jcall(writer,"saveBytes",Void,(jint,Array{jbyte,1},),index-1,bytes)
             next!(p)
           else
             #
             # add other types here (aside from UInt16)
             #
           end
      end

      # writer.close();
      jcall(writer, "close", Void, ())

end
