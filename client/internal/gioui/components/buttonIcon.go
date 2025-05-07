package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/icons"
	"client-go/internal/gioui/utils"
	"image"

	"gioui.org/io/event"
	"gioui.org/io/pointer"
	"gioui.org/layout"
	"gioui.org/op/clip"
)

type ButtonIconStyle struct {
	icon      icons.Icon
	width     int
	isPressed bool
	isHovered bool
	isActive  bool
	onClick   func()
}

func ButtonIcon(icon icons.Icon, width int, isActive bool, onClick func()) *ButtonIconStyle {
	return &ButtonIconStyle{
		icon:      icon,
		width:     width,
		isPressed: false,
		isHovered: false,
		isActive:  isActive,
		onClick:   onClick,
	}
}

func (b *ButtonIconStyle) Reset() {
	b.isPressed = false
	b.isHovered = false
}

func (b *ButtonIconStyle) Layout(gtx layout.Context, iconSize int) layout.Dimensions {
	gtx.Constraints.Min.X = max(iconSize+20, b.width)
	gtx.Constraints.Max.X = max(iconSize+20, b.width)
	gtx.Constraints.Min.Y = iconSize + 10
	gtx.Constraints.Max.Y = iconSize + 10

	bounds := image.Rect(0, 0, gtx.Constraints.Max.X, gtx.Constraints.Max.Y)
	area := clip.Rect(bounds).Push(gtx.Ops)

	event.Op(gtx.Ops, b.icon.Title+"button")
	pointer.CursorPointer.Add(gtx.Ops)

	for {
		ev, ok := gtx.Event(pointer.Filter{
			Target: b.icon.Title + "button",
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

	iconColor := colors.OnSurface
	if b.isActive {
		iconColor = colors.OnPrimary
	}

	layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return b.icon.DrawIcon(gtx.Ops, iconColor, 20, 0)
		})
	})

	return layout.Dimensions{Size: gtx.Constraints.Max}
}
