package gioui

import (
	"image/color"
	"log"
	"os"

	"gioui.org/app"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/widget/material"
)

func NewWindow() *app.Window {
	// Create a new window with a title and size.
	window := new(app.Window)

	err := run(window)
	if err != nil {
		log.Fatal(err)
	}

	return window
}

func run(window *app.Window) error {
	theme := material.NewTheme()
	var ops op.Ops
	split := NewSplit(0.25, 5)

	for {
		switch e := window.Event().(type) {
		case app.DestroyEvent:
			if e.Err != nil {
				log.Fatal(e.Err)
			}

			os.Exit(0)

		case app.FrameEvent:
			// This graphics context is used for managing the rendering state.
			gtx := app.NewContext(&ops, e)

			// split.Ratio = 0.2
			split.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
				return layout.Flex{Axis: layout.Vertical}.Layout(gtx,
					layout.Rigid(func(gtx layout.Context) layout.Dimensions {
						return FillWithLabel(gtx, theme, "Header", color.NRGBA{R: 0xFF, G: 0x00, B: 0x00, A: 0xFF})
					}),
					layout.Rigid(func(gtx layout.Context) layout.Dimensions {
						return ColorBox(gtx, gtx.Constraints.Max, color.NRGBA{R: 0x00, G: 0xFF, B: 0x00, A: 0xFF})
					}),
				)

			}, func(gtx layout.Context) layout.Dimensions {
				return FillWithLabel(gtx, theme, "Right", color.NRGBA{R: 0x00, G: 0x00, B: 0xFF, A: 0xFF})
			})

			// Pass the drawing operations to the GPU.
			e.Frame(gtx.Ops)
		}
	}
}
