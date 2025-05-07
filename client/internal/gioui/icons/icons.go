package icons

import (
	"image"
	"os"

	"image/color"
	_ "image/png" // Register PNG decoder

	"gioui.org/f32"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/paint"
)

type Icon struct {
	path  string
	Title string
	img   image.Image
}

var (
	Settings = Icon{path: "../assets/settings.png", Title: "settings"}
	Spinner  = Icon{path: "../assets/spinner.png", Title: "spinner"}
	Loader   = Icon{path: "../assets/loader.png", Title: "loader"}
	Plus     = Icon{path: "../assets/plus.png", Title: "plus"}
)

func LoadIcons() error {
	err := Settings.loadImage()
	if err != nil {
		return err
	}

	err = Spinner.loadImage()
	if err != nil {
		return err
	}

	err = Loader.loadImage()
	if err != nil {
		return err
	}

	err = Plus.loadImage()

	return err
}

// var Settings = loadImage("../assets/settings.png")
// var Spinner = loadImage("../assets/spinner.png")
// var Loader = loadImage("../assets/loader.png")
// var Plus = loadImage("../assets/plus.png")

// var ChatIcon = loadImage("../assets/chat.png")
// var ContactIcon = loadImage("../assets/contact.png")
// var SearchIcon = loadImage("../assets/search.png")

func (i *Icon) loadImage() error {
	imageFile, err := os.Open(i.path)
	if err != nil {
		return err
	}
	defer imageFile.Close()
	image, _, err := image.Decode(imageFile)

	if err != nil {
		return err
	}

	i.img = image
	return nil
}

func (i *Icon) DrawIcon(ops *op.Ops, iconColor color.NRGBA, size int, rotation float32) layout.Dimensions {
	sizeImg := i.img.Bounds().Size()
	rect := image.Rect(0, 0, sizeImg.X, sizeImg.Y)
	wImg := image.NewRGBA(rect)
	for x := range sizeImg.X {
		for y := range sizeImg.Y {
			pixel := i.img.At(x, y)
			originalColor := color.RGBAModel.Convert(pixel).(color.RGBA)

			c := iconColor
			c.A = originalColor.A
			wImg.Set(x, y, c)
		}
	}

	imageOp := paint.NewImageOp(wImg)
	imageOp.Filter = paint.FilterLinear
	imageOp.Add(ops)

	scale := float32(size) / float32(i.img.Bounds().Dx())

	op.Affine(f32.Affine2D{}.Rotate(f32.Pt(float32(size)/2, float32(size)/2), rotation)).Add(ops)
	op.Affine(f32.Affine2D{}.Scale(f32.Pt(0, 0), f32.Pt(scale, scale))).Add(ops)

	paint.PaintOp{}.Add(ops)

	return layout.Dimensions{Size: image.Pt(size, size)}
}
