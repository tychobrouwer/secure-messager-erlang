package chats

import (
	"gioui.org/layout"
	"gioui.org/widget/material"
)

func (p *Page) inputBar(gtx layout.Context, th *material.Theme) layout.Widget {
	return func(gtx layout.Context) layout.Dimensions {
		return layout.Flex{
			Axis:      layout.Horizontal,
			Alignment: layout.End,
		}.Layout(gtx,
			layout.Flexed(1,
				func(gtx layout.Context) layout.Dimensions {
					return p.chatInput.Layout(gtx, th)
				},
			),
			layout.Rigid(layout.Spacer{Width: 10}.Layout),
			layout.Rigid(
				func(gtx layout.Context) layout.Dimensions {
					return p.sendButton.Layout(gtx, th)
				},
			),
		)
	}
}
