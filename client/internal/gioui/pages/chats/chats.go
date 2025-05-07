package chats

import (
	"client-go/internal/client"
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/components"
	"client-go/internal/gioui/icons"
	page "client-go/internal/gioui/pages"
	"client-go/internal/gioui/utils"
	"fmt"
	"log"

	"gioui.org/font"
	"gioui.org/layout"
	"gioui.org/widget/material"
)

type Page struct {
	*page.Router
	client         *client.Client
	split          *components.SplitStyle
	selectedIdx    int
	selectedChat   []byte
	chatAddOpen    bool
	addFriendInput *components.InputStyle
}

func New(r *page.Router, c *client.Client) *Page {
	c.ListenIncomingMessages()

	return &Page{
		Router:         r,
		client:         c,
		split:          components.Split(0.25, 0.18, 0.5, 5),
		selectedIdx:    -1,
		selectedChat:   nil,
		chatAddOpen:    false,
		addFriendInput: components.Input("Add friend"),
	}
}

var _ page.Page = &Page{}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	utils.ColorBox(gtx, colors.Surface)

	p.split.Layout(gtx,
		// -------------------------------------------------------------
		// Left side
		// -------------------------------------------------------------
		func(gtx layout.Context) layout.Dimensions {
			utils.ColorBox(gtx, colors.SurfaceContainerLowest)
			return layout.Inset{
				Top:    5,
				Bottom: 5,
				Left:   10,
				Right:  10,
			}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
				return layout.Flex{Axis: layout.Vertical}.Layout(gtx,
					layout.Rigid(
						func(gtx layout.Context) layout.Dimensions {
							return p.chatHeader(th)(gtx)
						},
					),
					layout.Rigid(
						func(gtx layout.Context) layout.Dimensions {
							if p.chatAddOpen {
								return p.chatAdd(gtx, th)(gtx)
							} else {
								return p.chatList(gtx, th)(gtx)
							}
						},
					),
				)
			})
		},

		// -------------------------------------------------------------
		// Right side
		// -------------------------------------------------------------
		func(gtx layout.Context) layout.Dimensions {
			utils.ColorBox(gtx, colors.SurfaceContainerLow)

			return layout.Inset{
				Top:    5,
				Bottom: 5,
				Left:   10,
				Right:  10,
			}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
				return p.chatHistory(gtx, th)(gtx)
			})
		},
	)

	return layout.Dimensions{Size: gtx.Constraints.Max}
}

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
				func(gtx layout.Context) layout.Dimensions {
					return components.ButtonIcon(icons.Plus, 1, p.chatAddOpen, func() {
						p.chatAddOpen = !p.chatAddOpen
					}).Layout(gtx, 20)
				},
			),
		)
	}
}

func (p *Page) chatList(gtx layout.Context, th *material.Theme) layout.Widget {
	chats := p.client.GetContactIDs()

	if len(chats) > 0 && p.selectedIdx == -1 {
		p.selectedIdx = 0
		p.selectedChat = chats[0]
	}

	list := layout.List{Axis: layout.Vertical}

	utils.ColorBox(gtx, colors.SurfaceContainerLowest)
	return func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{
			Top:    10,
			Bottom: 5,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return list.Layout(gtx, len(chats), func(gtx layout.Context, index int) layout.Dimensions {
				return layout.Inset{
					Bottom: 5,
				}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
					gtx.Constraints.Max.Y = 60

					title := fmt.Sprintf("%x", chats[index])

					return components.Button(title, -1, p.selectedIdx == index, func() {
						p.selectedIdx = index
						p.selectedChat = chats[index]
					}).Layout(gtx, th)
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
						return components.Button("Add", 50, false, func() {
							friendID := p.addFriendInput.Editor.Text()

							if len(friendID) == 0 {
								return
							}

							err := p.client.AddContact([]byte(friendID))
							if err != nil {
								p.addFriendInput.Editor.SetText("")
								return
							}

							p.chatAddOpen = false
							p.addFriendInput.Editor.SetText("")

							log.Printf("Added friend: %s", friendID)
						}).Layout(gtx, th)
					},
				),
			)
		})
	}
}

func (p *Page) chatHistory(gtx layout.Context, th *material.Theme) layout.Widget {
	utils.ColorBox(gtx, colors.SurfaceContainerLow)
	chats, err := p.client.GetContactChatHistory(p.selectedChat)

	if err != nil {
		return func(gtx layout.Context) layout.Dimensions {
			return layout.Center.Layout(gtx, material.Label(th, 18, "error loading chat history").Layout)
		}
	}

	list := layout.List{Axis: layout.Vertical}

	return func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{
			Top:    10,
			Bottom: 5,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return list.Layout(gtx, len(chats), func(gtx layout.Context, index int) layout.Dimensions {
				return layout.Inset{
					Bottom: 30,
				}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
					gtx.Constraints.Max.Y = 60

					return material.Label(th, 18, string(chats[index].PlainMessage)).Layout(gtx)
				})
			})
		})
	}
}
