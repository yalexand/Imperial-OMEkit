include("bioformats.jl")
include("utils.jl")

using Images, ImageView

filename = "..\\TestData\\fluor.OME.tiff"

r = bfGetReader(filename)

angles = bfGetModulo(r,"Z")
display(angles)

I = bfGetVolume(r)
display_image(I[:,:,140,1,1])
#
sinogram = squeeze(sum(I,1),(1,4,5))
display_image(sinogram)
