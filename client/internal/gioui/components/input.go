package components

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"
	"strings"

	"gioui.org/font"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/paint"
	"gioui.org/widget"
	"gioui.org/widget/material"
)

type InputStyle struct {
	Editor   *widget.Editor
	hint     string
	maxLines int
}

func Input(hint string, maxLines int) *InputStyle {
	singleLine := maxLines == 1

	return &InputStyle{
		Editor:   &widget.Editor{SingleLine: singleLine},
		hint:     hint,
		maxLines: maxLines,
	}
}

func (e *InputStyle) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
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

	macroHint := op.Record(gtx.Ops)
	layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		tl := widget.Label{MaxLines: e.maxLines}
		return tl.Layout(gtx, th.Shaper, font, 16, e.hint, hintColor)
	})
	callHint := macroHint.Stop()

	macroText := op.Record(gtx.Ops)
	dims := layout.Inset{
		Top:    5,
		Bottom: 5,
		Left:   10,
		Right:  10,
	}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return e.Editor.Layout(gtx, th.Shaper, font, 16, textColor, selectionColor)
	})
	callText := macroText.Stop()

	gtx.Constraints.Min.X = gtx.Constraints.Max.X
	gtx.Constraints.Max.Y = dims.Size.Y
	gtx.Constraints.Min.Y = gtx.Constraints.Max.Y

	textLines := strings.Split(e.Editor.Text(), "\n")
	if textLines[len(textLines)-1] != "" && len(textLines) != 1 {
		gtx.Constraints.Max.Y = gtx.Constraints.Max.Y + 1
		gtx.Constraints.Min.Y = gtx.Constraints.Min.Y + 1
	}

	utils.ColorRoundBox(gtx, colors.SurfaceContainer, 5)

	callText.Add(gtx.Ops)
	if e.Editor.Len() == 0 {
		callHint.Add(gtx.Ops)
	}

	return layout.Dimensions{Size: gtx.Constraints.Max}
}
