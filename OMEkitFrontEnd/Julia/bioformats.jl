using JavaCall, XMLDict

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

# const JBioformatsPlus = @jimport bioformats_plus


###########################################
function Base.isempty(modlo::JavaCall.JavaObject{Symbol("loci.formats.Modulo")})
    len = jcall(modlo, "length", jint, ())
    return len == 0
end

###########################################
function bfGetModulo(r,dim)
  ret = []
        modlo = jcall(r, "getModulo"*dim, JModulo, ())
        #
        if !isempty(modlo)
          try
              anno = jcall(modlo,"toXMLAnnotation",JString,())
              xml = parse_xml(anno)
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
          #
          #  TODO: get data via "labels"
          #
        end
  return ret
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
function bfGetPlane(pixelType,bpp,fp,sgn,little,sizeX,sizeY,plane)

    I = []

    arr = reinterpret(jshort,plane)

    for k=1:length(arr)
      arr[k]=bswap(arr[k])
    end

    I = reshape(float(arr),Int64(sizeX),Int64(sizeY))

end

##########################
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
