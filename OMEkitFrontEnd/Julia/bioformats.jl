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

###########################################
#
# TODO: possibly implement via Java by using Modulo set/get functions
#
function bfGetModulo(r,dim)
  ret = []
        modlo = jcall(r, "getModulo"*dim, JModulo, ())

        anno = jcall(modlo,"toXMLAnnotation",JString,())
        xml = parse_xml(anno)

        if ! ("other"== xml[:Type])

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
