include("tomography.jl")
include("utils.jl")

angles = (0:1:359)/360*2*pi; # [rad]

z = shepp_logan(1000; highContrast=true)
ImageView.imshow(z)

z = float(z)

tic();
sinogram = radon(z,angles)
display(toc())
display_image(sinogram)

tic();
reconstruction = iradon(sinogram,angles)
display(toc())
display_image(reconstruction)
