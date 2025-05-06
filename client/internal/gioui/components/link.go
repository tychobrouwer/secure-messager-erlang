package components

import (
	"client-go/internal/gioui/colors"
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

type LinkStyle struct {
	title     string
	isPressed bool
	isHovered bool
	onClick   func()
}

func Link(title string, onClick func()) *LinkStyle {
	return &LinkStyle{
		title:     title,
		isPressed: false,
		isHovered: false,
		onClick:   onClick,
	}
}

func (l *LinkStyle) Reset() {
	l.isPressed = false
	l.isHovered = false
}

func (l *LinkStyle) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {

	font := font.Font{
		Typeface: th.Face,
	}

	measureMacro := op.Record(gtx.Ops)
	tl := widget.Label{}
	dims := tl.Layout(gtx, th.Shaper, font, 12, l.title, op.CallOp{})
	measureMacro.Stop()

	gtx.Constraints.Min.X = dims.Size.X
	gtx.Constraints.Max.X = dims.Size.X
	gtx.Constraints.Min.Y = dims.Size.Y
	gtx.Constraints.Max.Y = dims.Size.Y

	bounds := image.Rect(0, 0, gtx.Constraints.Max.X, gtx.Constraints.Max.Y)
	area := clip.Rect(bounds).Push(gtx.Ops)

	event.Op(gtx.Ops, l.title+"link")
	pointer.CursorPointer.Add(gtx.Ops)

	for {
		ev, ok := gtx.Event(pointer.Filter{
			Target: l.title + "link",
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
			l.onClick()
			l.isPressed = true
		case pointer.Release:
			l.isPressed = false
		case pointer.Enter:
			l.isHovered = true
		case pointer.Leave:
			l.isHovered = false
		}
	}

	area.Pop()

	textColor := colors.OnPrimary
	if l.isHovered {
		textColor = colors.OnPrimaryVariant
	}

	colorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: textColor}.Add(gtx.Ops)
	colorOp := colorMacro.Stop()

	colorOp.Add(gtx.Ops)

	return tl.Layout(gtx, th.Shaper, font, 12, l.title, colorOp)
}
