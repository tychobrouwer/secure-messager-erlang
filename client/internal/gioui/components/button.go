package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"
	"image"

	"gioui.org/font"
	"gioui.org/io/event"
	"gioui.org/io/pointer"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/clip"
	"gioui.org/op/paint"
	"gioui.org/widget"
	"gioui.org/widget/material"
)

type ButtonStyle struct {
	title     string
	width     int
	isPressed bool
	isHovered bool
	isActive  bool
	onClick   func()
}

func Button(title string, width int, isActive bool, onClick func()) *ButtonStyle {
	return &ButtonStyle{
		title:     title,
		width:     width,
		isPressed: false,
		isHovered: false,
		isActive:  isActive,
		onClick:   onClick,
	}
}

func (b *ButtonStyle) Reset() {
	b.isPressed = false
	b.isHovered = false
}

func (b *ButtonStyle) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	textColor := colors.OnSurface
	if b.isActive {
		textColor = colors.OnPrimary
	}

	textColorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: textColor}.Add(gtx.Ops)
	textColorOp := textColorMacro.Stop()

	font := font.Font{
		Typeface: th.Face,
	}

	macro := op.Record(gtx.Ops)
	tl := widget.Label{}
	dims := tl.Layout(gtx, th.Shaper, font, 16, b.title, textColorOp)
	call := macro.Stop()

	gtx.Constraints.Min.X = max(dims.Size.X+20, b.width)
	gtx.Constraints.Max.X = max(dims.Size.X+20, b.width)
	gtx.Constraints.Min.Y = dims.Size.Y + 10
	gtx.Constraints.Max.Y = dims.Size.Y + 10

	bounds := image.Rect(0, 0, gtx.Constraints.Max.X, gtx.Constraints.Max.Y)
	area := clip.Rect(bounds).Push(gtx.Ops)

	event.Op(gtx.Ops, b.title+"button")
	pointer.CursorPointer.Add(gtx.Ops)

	for {
		ev, ok := gtx.Event(pointer.Filter{
			Target: b.title + "button",
			Kinds:  pointer.Press | pointer.Release | pointer.Enter | pointer.Leave,
		})
		if !ok {
			break
		}

		e, ok := ev.(pointer.Event)
		if !ok {
			continue
		}

		switch e.Kind {
		case pointer.Press:
			b.onClick()
			b.isPressed = true
		case pointer.Release:
			b.isPressed = false
		case pointer.Enter:
			b.isHovered = true
		case pointer.Leave:
			b.isHovered = false
		}
	}

	area.Pop()

	if b.isActive {
		utils.ColorRoundBox(gtx, colors.Primary, 5)
	} else if b.isPressed {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHighest, 5)
	} else if b.isHovered {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHigh, 5)
	} else {
		utils.ColorRoundBox(gtx, colors.SurfaceContainer, 5)
	}

	layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			call.Add(gtx.Ops)

			return dims
		})

	})

	return layout.Dimensions{Size: gtx.Constraints.Max}
}
