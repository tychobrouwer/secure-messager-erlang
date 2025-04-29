package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"
	"image"

	"gioui.org/font"
	"gioui.org/io/event"
	"gioui.org/io/pointer"
	"gioui.org/layout"
	"gioui.org/op/clip"
	"gioui.org/unit"
	"gioui.org/widget/material"
)

type Button struct {
	title     string
	isPressed bool
	isHovered bool
	isActive  bool
	onClick   func()
}

func NewButton(title string, isActive bool, onClick func()) *Button {
	return &Button{
		title:     title,
		isPressed: false,
		isHovered: false,
		isActive:  isActive,
		onClick:   onClick,
	}
}

func (b *Button) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	bounds := image.Rect(0, 0, gtx.Constraints.Max.X, gtx.Constraints.Max.Y)
	area := clip.Rect(bounds).Push(gtx.Ops)

	event.Op(gtx.Ops, b.title)
	pointer.CursorPointer.Add(gtx.Ops)

	for {
		ev, ok := gtx.Event(pointer.Filter{
			Target: b.title,
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
			if !b.isPressed {
				b.onClick()
			}

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

	textColor := colors.OnSurface
	if b.isActive {
		utils.ColorRoundBox(gtx, colors.Primary, 5)
		textColor = colors.OnPrimary
	} else if b.isPressed {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHighest, 5)
	} else if b.isHovered {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHigh, 5)
	} else {
		utils.ColorRoundBox(gtx, colors.SurfaceContainer, 5)
	}

	return layout.Inset{
		Top:    2,
		Bottom: 2,
		Left:   8,
		Right:  8,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		size := gtx.Dp(12)

		text := material.Label(th, unit.Sp(size), b.title)
		text.Color = textColor
		text.Font.Weight = font.Bold

		return text.Layout(gtx)
	})
}
