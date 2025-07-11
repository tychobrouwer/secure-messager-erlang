package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/icons"
	"client-go/internal/gioui/utils"
	"image"

	"gioui.org/io/event"
	"gioui.org/io/pointer"
	"gioui.org/io/semantic"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/clip"
)

type ClickableButtonIcon struct {
	icon     icons.Icon
	width    int
	size     int
	isActive bool
	Click    Click
}

func ButtonIcon(icon icons.Icon, width int, size int, isActive bool) ClickableButtonIcon {
	return ClickableButtonIcon{
		icon:     icon,
		width:    width,
		size:     size,
		isActive: isActive,
		Click:    Click{},
	}
}

func (i *ClickableButtonIcon) SetActive(active bool) {
	i.isActive = active
}

func (i *ClickableButtonIcon) SetWidth(width int) {
	i.width = width
}

func (i *ClickableButtonIcon) SetOnClick(onClick func()) {
	i.Click.onClick = onClick
}

func (i *ClickableButtonIcon) Layout(gtx layout.Context) layout.Dimensions {
	return i.layout(i, gtx)
}

func (i *ClickableButtonIcon) layout(t event.Tag, gtx layout.Context) layout.Dimensions {
	i.Click.Update(gtx.Source)

	m := op.Record(gtx.Ops)

	iconColor := colors.OnSurface
	if i.isActive {
		iconColor = colors.OnPrimary
	}

	dims := layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return i.icon.DrawIcon(gtx.Ops, iconColor, 20, 0)
		})
	})

	c := m.Stop()

	defer clip.Rect(image.Rectangle{Max: dims.Size}).Push(gtx.Ops).Pop()
	pointer.CursorPointer.Add(gtx.Ops)

	semantic.EnabledOp(gtx.Enabled()).Add(gtx.Ops)
	i.Click.Add(gtx.Ops)
	event.Op(gtx.Ops, t)

	gtx.Constraints.Min.X = max(i.size+20, i.width)
	gtx.Constraints.Max.X = max(i.size+20, i.width)
	gtx.Constraints.Min.Y = i.size + 10
	gtx.Constraints.Max.Y = i.size + 10

	if i.isActive {
		utils.ColorRoundBox(gtx, colors.Primary, 5)
	} else if i.Click.pressed {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHighest, 5)
	} else if i.Click.hovered {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHigh, 5)
	} else {
		utils.ColorRoundBox(gtx, colors.SurfaceContainer, 5)
	}

	c.Add(gtx.Ops)
	return dims
}
