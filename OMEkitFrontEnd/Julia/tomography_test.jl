include("tomography.jl")

#########################################
using Images, ImageView

function display_image(I)
  v1 = minimum(I)
  v2 = maximum(I)
  todisplay = (I-v1)/(v2-v1)
  ImageView.imshow(todisplay)
end

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
