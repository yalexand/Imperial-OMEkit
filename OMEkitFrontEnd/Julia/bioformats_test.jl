include("bioformats.jl")

filename = "..\\TestData\\fluor.OME.tiff"

angles = getModulo(bfGetReader(filename),"Z")
display(angles)

I = bfopen(filename)
