include("bioformats.jl")
include("utils.jl")
include("tomography.jl")

filename = "..\\TestData\\fluor.OME.tiff"

r = bfGetReader(filename)

angles = bfGetModulo(r,"Z")
# bfGetModulo doesn't work for now, so just hard-code the angles
angles = (0:1:359)/360*2*pi; # [rad]

I = bfGetVolume(r)

# display one of the projections
display_image(I[:,:,140,1,1])
#
# reconstruct and display one of z-slices through 3d volume
z_slice = iradon(I[120,:,:,1,1],angles)
display_image(z_slice)
