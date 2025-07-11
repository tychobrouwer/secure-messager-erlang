package chats

import (
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"

	"gioui.org/font"
	"gioui.org/layout"
	"gioui.org/widget/material"
)

func (p *Page) chatHeader(th *material.Theme) layout.Widget {
	return func(gtx layout.Context) layout.Dimensions {
		utils.ColorBox(gtx, colors.SurfaceContainerLowest)
		return layout.Flex{
			Axis:      layout.Horizontal,
			Alignment: layout.Middle,
		}.Layout(gtx,
			layout.Flexed(1,
				func(gtx layout.Context) layout.Dimensions {
					text := material.Label(th, 20, "Chats")
					text.Color = colors.OnSurface
					text.Font.Weight = font.Bold

					return text.Layout(gtx)
				},
			),
			layout.Rigid(
				p.addFriendIcon.Layout,
			),
		)
	}
}

func (p *Page) chatList(gtx layout.Context, th *material.Theme) layout.Widget {
	list := layout.List{Axis: layout.Vertical}

	utils.ColorBox(gtx, colors.SurfaceContainerLowest)
	return func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{
			Top:    10,
			Bottom: 5,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return list.Layout(gtx, len(p.chatButtons), func(gtx layout.Context, index int) layout.Dimensions {
				return layout.Inset{
					Bottom: 5,
				}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
					gtx.Constraints.Max.Y = 60

					return p.chatButtons[index].Layout(gtx, th)
				})
			})
		})
	}
}

func (p *Page) chatAdd(gtx layout.Context, th *material.Theme) layout.Widget {
	utils.ColorBox(gtx, colors.SurfaceContainerLowest)

	return func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{
			Top:    10,
			Bottom: 5,
			Left:   10,
			Right:  10,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return layout.Flex{
				Axis: layout.Horizontal,
			}.Layout(gtx,
				layout.Flexed(1,
					func(gtx layout.Context) layout.Dimensions {
						return p.addFriendInput.Layout(gtx, th)
					},
				),
				layout.Rigid(layout.Spacer{Width: 10}.Layout),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return p.addFriendButton.Layout(gtx, th)
					},
				),
			)
		})
	}
}
