using Images, ImageView

function display_image(I)
  v1 = minimum(I)
  v2 = maximum(I)
  todisplay = (I-v1)/(v2-v1)
  ImageView.imshow(todisplay)
end
