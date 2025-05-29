package chats

import (
	"bytes"
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/utils"
	"image"

	"gioui.org/font"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/paint"
	"gioui.org/widget"
	"gioui.org/widget/material"
)

func (p *Page) chatHistory(gtx layout.Context, th *material.Theme) layout.Widget {
	utils.ColorBox(gtx, colors.SurfaceContainerLow)
	chats, err := p.client.GetContactChatHistory(p.selectedChat)

	if err != nil {
		return func(gtx layout.Context) layout.Dimensions {
			return layout.Center.Layout(gtx, material.Label(th, 18, "error loading chat history").Layout)
		}
	}

	list := layout.List{Axis: layout.Vertical}
	font := font.Font{
		Typeface: th.Face,
	}
	textColorMacro := op.Record(gtx.Ops)
	paint.ColorOp{Color: colors.OnSurface}.Add(gtx.Ops)
	textColorOp := textColorMacro.Stop()

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
						return list.Layout(gtx, len(chats), func(gtx layout.Context, index int) layout.Dimensions {
							return layout.Inset{
								Bottom: 5,
							}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
								leftWidth := float32(0.0)
								rightWith := float32(1.0)
								if bytes.Equal(chats[index].SenderIDHash, p.client.IDHash) {
									leftWidth = 1.0
									rightWith = 0.0
								}

								return layout.Flex{
									Axis: layout.Horizontal,
								}.Layout(gtx,
									layout.Flexed(leftWidth,
										func(gtx layout.Context) layout.Dimensions {
											return layout.Dimensions{
												Size: image.Point{
													X: gtx.Constraints.Max.X,
													Y: gtx.Constraints.Min.Y,
												},
											}
										},
									),
									layout.Rigid(
										func(gtx layout.Context) layout.Dimensions {
											m := op.Record(gtx.Ops)
											dims := layout.Inset{
												Left:   10,
												Right:  10,
												Top:    2,
												Bottom: 3,
											}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
												return layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
													tl := widget.Label{}
													return tl.Layout(gtx, th.Shaper, font, 16, string(chats[index].PlainMessage), textColorOp)
												})
											})
											c := m.Stop()

											gtx.Constraints.Min.X = dims.Size.X
											gtx.Constraints.Max.X = dims.Size.X
											gtx.Constraints.Min.Y = dims.Size.Y
											gtx.Constraints.Max.Y = dims.Size.Y

											utils.ColorRoundBox(gtx, colors.SurfaceContainerHigh, 5)

											c.Add(gtx.Ops)
											return dims
										},
									),
									layout.Flexed(rightWith,
										func(gtx layout.Context) layout.Dimensions {
											return layout.Dimensions{
												Size: image.Point{
													X: gtx.Constraints.Max.X,
													Y: gtx.Constraints.Min.Y,
												},
											}
										},
									),
								)
							})
						})
					},
				),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
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
					},
				),
			)
		})
	}
}
