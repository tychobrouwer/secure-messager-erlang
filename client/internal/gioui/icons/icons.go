package icons

import (
	"image"
	"os"

	"image/color"
	_ "image/png" // Register PNG decoder

	"gioui.org/f32"
	"gioui.org/op"
	"gioui.org/op/paint"
)

var Settings = loadImage("../assets/settings.png")
var Spinner = loadImage("../assets/spinner.png")
var Loader = loadImage("../assets/loader.png")

// var ChatIcon = loadImage("../assets/chat.png")
// var ContactIcon = loadImage("../assets/contact.png")
// var SearchIcon = loadImage("../assets/search.png")

func loadImage(path string) image.Image {
	imageFile, err := os.Open(path)
	if err != nil {
		panic("failed to open image: " + err.Error())
	}
	defer imageFile.Close()
	image, _, err := image.Decode(imageFile)

	if err != nil {
		panic("failed to load image: " + err.Error())
	}
	return image
}

func DrawIcon(ops *op.Ops, img image.Image, iconColor color.NRGBA, size int, rotation float32) {
	sizeImg := img.Bounds().Size()
	rect := image.Rect(0, 0, sizeImg.X, sizeImg.Y)
	wImg := image.NewRGBA(rect)
	for x := range sizeImg.X {
		for y := range sizeImg.Y {
			pixel := img.At(x, y)
			originalColor := color.RGBAModel.Convert(pixel).(color.RGBA)

			c := iconColor
			c.A = originalColor.A
			wImg.Set(x, y, c)
		}
	}

	imageOp := paint.NewImageOp(wImg)
	imageOp.Filter = paint.FilterLinear
	imageOp.Add(ops)

	scale := float32(size) / float32(img.Bounds().Dx())

	op.Affine(f32.Affine2D{}.Rotate(f32.Pt(float32(size)/2, float32(size)/2), rotation)).Add(ops)
	op.Affine(f32.Affine2D{}.Scale(f32.Pt(0, 0), f32.Pt(scale, scale))).Add(ops)

	paint.PaintOp{}.Add(ops)
}
