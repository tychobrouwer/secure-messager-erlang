package icons

import (
	"image"
	"os"

	_ "image/png" // Register PNG decoder

	"gioui.org/f32"
	"gioui.org/op"
	"gioui.org/op/paint"
)

var SettingsIcon = loadImage("../assets/settings.png")

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

func DrawIcon(ops *op.Ops, img image.Image, size int) {
	imageOp := paint.NewImageOp(img)
	imageOp.Filter = paint.FilterNearest
	imageOp.Add(ops)

	scale := float32(size) / float32(img.Bounds().Size().X)

	op.Affine(f32.Affine2D{}.Scale(f32.Pt(0, 0), f32.Pt(scale, scale))).Add(ops)
	paint.PaintOp{}.Add(ops)
}
