include("bioformats.jl")
include("utils.jl")

using Images, ImageView

filename = "..\\TestData\\fluor.OME.tiff"

angles = getModulo(bfGetReader(filename),"Z")
display(angles)

I = bfopen(filename)
display_image(I[:,:,140,1,1])
