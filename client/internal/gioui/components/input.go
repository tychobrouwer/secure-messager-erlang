package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"

	"gioui.org/font"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/paint"
	"gioui.org/widget"
	"gioui.org/widget/material"
)

type InputStyle struct {
	Editor *widget.Editor
	hint   string
}

func Input(hint string) *InputStyle {
	return &InputStyle{
		Editor: &widget.Editor{SingleLine: true},
		hint:   hint,
	}
}

func (e InputStyle) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	textColorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: colors.OnSurface}.Add(gtx.Ops)
	textColor := textColorMacro.Stop()
	hintColorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: colors.OnSurfaceVariant}.Add(gtx.Ops)
	hintColor := hintColorMacro.Stop()
	selectionColorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: colors.Primary}.Add(gtx.Ops)
	selectionColor := selectionColorMacro.Stop()

	font := font.Font{
		Typeface: th.Face,
	}

	macro := op.Record(gtx.Ops)
	tl := widget.Label{MaxLines: 1}
	dims := tl.Layout(gtx, th.Shaper, font, 16, e.hint, hintColor)
	call := macro.Stop()

	gtx.Constraints.Min.X = gtx.Constraints.Max.X
	gtx.Constraints.Min.Y = dims.Size.Y + 10
	gtx.Constraints.Max.Y = dims.Size.Y + 10

	utils.ColorRoundBox(gtx, colors.SurfaceContainer, 5)

	layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		dims = e.Editor.Layout(gtx, th.Shaper, font, 16, textColor, selectionColor)
		if e.Editor.Len() == 0 {
			call.Add(gtx.Ops)
		}

		return dims
	})

	return layout.Dimensions{Size: gtx.Constraints.Max}
}
