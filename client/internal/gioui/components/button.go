package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"
	"image"

	"gioui.org/font"
	"gioui.org/io/event"
	"gioui.org/io/pointer"
	"gioui.org/io/semantic"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/clip"
	"gioui.org/op/paint"
	"gioui.org/widget"
	"gioui.org/widget/material"
)

type ClickableButton struct {
	title    string
	width    int
	isActive bool
	Click    Click
}

func Button(title string, width int) ClickableButton {
	return ClickableButton{
		title:    title,
		isActive: false,
		width:    width,
		Click:    Click{},
	}
}

func (b *ClickableButton) SetActive(active bool) {
	b.isActive = active
}

func (b *ClickableButton) SetWidth(width int) {
	b.width = width
}

func (b *ClickableButton) SetOnClick(onClick func()) {
	b.Click.onClick = onClick
}

func (b *ClickableButton) SetTitle(title string) {
	b.title = title
}

func (b *ClickableButton) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	return b.layout(b, gtx, th)
}

func (b *ClickableButton) layout(t event.Tag, gtx layout.Context, th *material.Theme) layout.Dimensions {
	b.Click.Update(gtx.Source)

	m := op.Record(gtx.Ops)
	textColor := colors.OnSurface

	textColorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: textColor}.Add(gtx.Ops)
	textColorOp := textColorMacro.Stop()

	font := font.Font{
		Typeface: th.Face,
	}

	dims := layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			tl := widget.Label{}
			return tl.Layout(gtx, th.Shaper, font, 16, b.title, textColorOp)
		})
	})

	c := m.Stop()

	defer clip.Rect(image.Rectangle{Max: dims.Size}).Push(gtx.Ops).Pop()
	pointer.CursorPointer.Add(gtx.Ops)

	semantic.EnabledOp(gtx.Enabled()).Add(gtx.Ops)
	b.Click.Add(gtx.Ops)
	event.Op(gtx.Ops, t)

	if b.width > 0 {
		gtx.Constraints.Min.X = dims.Size.X
		gtx.Constraints.Max.X = dims.Size.X
	}
	gtx.Constraints.Min.Y = dims.Size.Y
	gtx.Constraints.Max.Y = dims.Size.Y

	if b.isActive {
		utils.ColorRoundBox(gtx, colors.Primary, 5)
	} else if b.Click.pressed {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHighest, 5)
	} else if b.Click.hovered {
		utils.ColorRoundBox(gtx, colors.SurfaceContainerHigh, 5)
	} else {
		utils.ColorRoundBox(gtx, colors.SurfaceContainer, 5)
	}

	c.Add(gtx.Ops)
	return dims
}
