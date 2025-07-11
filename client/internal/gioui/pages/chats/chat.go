package chats

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"

	"gioui.org/layout"
	"gioui.org/widget/material"
)

func (p *Page) chat(gtx layout.Context, th *material.Theme) layout.Widget {
	utils.ColorBox(gtx, colors.SurfaceContainerLow)

	return func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{
			Top:    10,
			Bottom: 5,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return layout.Flex{
				Axis: layout.Vertical,
			}.Layout(gtx,
				layout.Flexed(
					1.0,
					func(gtx layout.Context) layout.Dimensions {
						return layout.Inset{
							Left:  30,
							Right: 30,
						}.Layout(gtx, p.chatHistory(gtx, th))
					},
				),
				layout.Rigid(
					p.inputBar(gtx, th),
				),
			)
		})
	}
}
