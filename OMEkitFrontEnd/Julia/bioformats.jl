using JavaCall

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
function Base.isempty(modlo::JavaCall.JavaObject{Symbol("loci.formats.Modulo")})
    len = jcall(modlo, "length", jint, ())
    return len == 0
end

###########################################
function getModulo(r,dim)

func_name = "getModulo"*dim;

ret = [];

        modlo = jcall(r, func_name, JModulo, ())

        if !isempty(modlo)
          #
          # TO IMPLEMENT MODULO DATA ACCORDING TO MATLAB TEMPLATE BELOW ...
          #
          #
          #           if !isempty(modlo.labels)
          #               # ret = str2num(modlo.labels)'; %Matlab
          #               # needs an equivalent
          #           end
          #
          #           if !isempty(modlo.start)
          #             if modlo.end > modlo.start
          #               nsteps = round((modlo.end - modlo.start)/modlo.step)
          #               ret = 0:nsteps
          #               ret = ret*modlo.step
          #               ret = ret + modlo.start
          #             end
          #           end
        end

return ret

end

##########################
function bfGetReader(filename)
  # same as `new ChannelFiller()`
  # empty tuple `()` here means that constructor doesn't take any args
  r = JChannelFiller(())

  # same as new ChannelSeparator(r)
  # again, first argument - `(JChannelFiller,)` - a tuple of input types
  # the rest - `r` - is a list of actual arguments
  r = JChannelSeparator((JIFormatReader,), r)

  # same as `new OMEXMLServiceImpl()`
  OMEXMLService = JOMEXMLServiceImpl(())

  # same as `meta = OMEXMLService.createMEXMLMetadata()`
  meta = jcall(OMEXMLService, "createOMEXMLMetadata", JOMEXMLMetadata, ())

  # same as `r.setMetadataStore(meta)`
  jcall(r, "setMetadataStore", Void, (JMetadataStore,), meta)

  # r.setId(full_filename);
  jcall(r, "setId", Void, (JString,), filename)

  return r;
end

##########################
function bfopen(id)

  omeMeta = [];

  # % initialize logging - THAT DOESN'T WORK BY SOME REASON
  #
  # loci.common.DebugTools.enableLogging('INFO');
  # jcall(JDebugTools, "enableLogging", Void, (JString,), "INFO")

  r = bfGetReader(id);

  sizeX = jcall(r, "getSizeX", jint, ())
  sizeY = jcall(r, "getSizeY", jint, ())
  sizeZ = jcall(r, "getSizeZ", jint, ())
  sizeC = jcall(r, "getSizeC", jint, ())
  sizeT = jcall(r, "getSizeT", jint, ())

  # for debug
  display(sizeX)
  display(sizeY)
  display(sizeZ)
  display(sizeC)
  display(sizeT)

  pixelType = jcall(r, "getPixelType", jint, ())
  bpp = jcall(JFormatTools,"getBytesPerPixel",jint, (jint,), pixelType)
  fp = jcall(JFormatTools,"isFloatingPoint",jboolean, (jint,), pixelType)
  sgn = jcall(JFormatTools,"isSigned",jboolean, (jint,), pixelType)
  little = jcall(r, "isLittleEndian", jboolean, ())

  # arr - should be Julia XY image at index=1
  iPlane = 1;
  arr = bfGetPlane(pixelType,bpp,fp,sgn,little,
            jcall(r, "openBytes", Array{jbyte, 1}, (jint,), iPlane))

  #
  # TO IMPLEMENT IMAGE OPEN ...
  #

  return omeMeta;

end

##################################
function bfGetPlane(pixelType,bpp,fp,sgn,little, plane)

I = []

#
# TO IMPLEMENT CONVERSION FROM JAVA BYTE ARRAY TO JULIA IMAGE ...
#

# if 2==bpp
#     # I = jcall(JDataTools,"makeDataArray", Array{jchar, 1}, Array{jbyte, 1}, (jint,), (jint,), (jboolean,), plane, bpp, fp, little)
#     I = jcall(JDataTools,"makeDataArray", Array{jchar, 1},
#                         Array{jbyte, 1}, plane,
#                         (jint,), bpp,
#                         (jint,), fp,
#                         (jboolean,), little)
# end

return I

end
