include("bioformats.jl")
include("utils.jl")
include("tomography.jl")

filename = "..\\TestData\\fluor.OME.tiff"

r = bfGetReader(filename)

I = bfGetVolume(r)

# display one of the projections
display_image(I[:,:,140,1,1])
#
# reconstruct and display one of z-slices through 3d volume
angles = bfGetModulo(r,"Z") # [degree]
z_slice = iradon(I[120,:,:,1,1],angles/360*2*pi) # [rad]
display_image(z_slice)

jcall(r, "close", Void, ())
