package components

import (
	"client-go/internal/gioui/colors"
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

type ClickableButtonLink struct {
	title string
	Click Click
}

func ButtonLink(title string) ClickableButtonLink {
	return ClickableButtonLink{
		title: title,
		Click: Click{},
	}
}

func (l *ClickableButtonLink) SetOnClick(onClick func()) {
	l.Click.onClick = onClick
}

func (l *ClickableButtonLink) SetTitle(title string) {
	l.title = title
}

func (l *ClickableButtonLink) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	return l.layout(l, gtx, th)
}

func (l *ClickableButtonLink) layout(t event.Tag, gtx layout.Context, th *material.Theme) layout.Dimensions {
	l.Click.Update(gtx.Source)

	m := op.Record(gtx.Ops)

	font := font.Font{
		Typeface: th.Face,
	}

	textColor := colors.OnPrimary
	if l.Click.hovered {
		textColor = colors.OnPrimaryVariant
	}
	colorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: textColor}.Add(gtx.Ops)
	colorOp := colorMacro.Stop()

	tl := widget.Label{}
	dims := tl.Layout(gtx, th.Shaper, font, 12, l.title, colorOp)

	c := m.Stop()

	defer clip.Rect(image.Rectangle{Max: dims.Size}).Push(gtx.Ops).Pop()
	pointer.CursorPointer.Add(gtx.Ops)

	semantic.EnabledOp(gtx.Enabled()).Add(gtx.Ops)
	l.Click.Add(gtx.Ops)
	event.Op(gtx.Ops, t)

	gtx.Constraints.Min.X = dims.Size.X
	gtx.Constraints.Max.X = dims.Size.X
	gtx.Constraints.Min.Y = dims.Size.Y
	gtx.Constraints.Max.Y = dims.Size.Y

	c.Add(gtx.Ops)
	return dims
}
