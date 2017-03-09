include("tomography.jl")

#########################################
using Images, ImageView

#JULIA_NUM_THREADS=2
#Base.FFTW.set_num_threads(8)
#julia5 -O3 --math-mode=fast

angles = (0:1:359)/360*2*pi; # [rad]

z = shepp_logan(1000; highContrast=true);
ImageView.imshow(z)

z = float(z);

tic();
sinogram = radon(z,angles);
#sinogram = radon_multithreaded(z,angles);
#sinogram = radon_TimHoly(z,angles);
#sinogram = radon_TimHoly_multithreaded(z,angles);
display(toc());

display(size(sinogram));

v1 = minimum(sinogram);
v2 = maximum(sinogram);
todisplay = (sinogram-v1)/(v2-v1);
ImageView.imshow(todisplay);

tic();
reconstruction = iradon(sinogram,angles);
display(toc());

v1 = minimum(reconstruction);
v2 = maximum(reconstruction);
todisplay = (reconstruction-v1)/(v2-v1);
ImageView.imshow(todisplay);
