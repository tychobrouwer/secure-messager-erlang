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
	client          *client.Client
	split           *components.SplitStyle
	selectedIdx     int
	selectedChat    []byte
	chatAddOpen     bool
	initialized     bool
	chatButtons     []components.ClickableButton
	addFriendInput  *components.InputStyle
	chatInput       *components.InputStyle
	sendButton      components.ClickableButton
	addFriendButton components.ClickableButton
	addFriendIcon   components.ClickableButtonIcon
}

func New(r *page.Router, c *client.Client) *Page {
	c.ListenIncomingMessages()

	return &Page{
		Router:          r,
		client:          c,
		split:           components.Split(0.3, 0.20, 0.5, 220, 1000, 5),
		selectedIdx:     -1,
		selectedChat:    nil,
		chatAddOpen:     false,
		initialized:     false,
		chatButtons:     make([]components.ClickableButton, 0),
		addFriendInput:  components.Input("Add friend", 1),
		chatInput:       components.Input("Type a message", 0),
		sendButton:      components.Button("Send", 50),
		addFriendButton: components.Button("Add", 50),
		addFriendIcon:   components.ButtonIcon(icons.Plus, 1, 20, false),
	}
}

var _ page.Page = &Page{}

func (p *Page) UpdateChats() {
	chats := p.client.GetContactIDs()

	if len(chats) > 0 && p.selectedIdx == -1 {
		p.selectedIdx = 0
		p.selectedChat = chats[0]
	}

	p.chatButtons = make([]components.ClickableButton, len(chats))
	for i := range chats {
		messagePayload := &client.ReceiveMessagePayload{
			ContactIDHash:     chats[i],
			StartingTimestamp: p.client.LastPolledTimestamp,
		}
		p.client.RequestMessages(messagePayload)

		p.chatButtons[i] = components.Button(fmt.Sprintf("%x", chats[i]), 50)
		p.chatButtons[i].SetOnClick(func() {
			if p.selectedIdx != i {
				p.chatButtons[p.selectedIdx].SetActive(false)
				p.chatButtons[i].SetActive(true)
				p.chatInput.Editor.SetText("")

				p.selectedIdx = i
				p.selectedChat = chats[i]
			}
		})
	}
}

func (p *Page) sendMessage() {
	message := p.chatInput.Editor.Text()
	if len(message) == 0 {
		return
	}

	err := p.client.SendMessage(p.selectedChat, []byte(message))
	if err != nil {
		log.Printf("Failed to send message: %v", err)
		return
	}

	p.UpdateChats()

	p.chatInput.Editor.SetText("")
}

func (p *Page) addFriend() {
	friendID := p.addFriendInput.Editor.Text()

	if len(friendID) == 0 {
		return
	}

	err := p.client.AddContact([]byte(friendID))
	if err != nil {
		return
	}

	p.chatAddOpen = false
	p.addFriendInput.Editor.SetText("")

	p.UpdateChats()

	log.Printf("Added friend: %s", friendID)
}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	if !p.initialized {
		p.UpdateChats()
		p.sendButton.SetOnClick(p.sendMessage)
		p.addFriendIcon.SetOnClick(func() {
			p.chatAddOpen = !p.chatAddOpen
		})
		p.addFriendButton.SetOnClick(p.addFriend)
		if len(p.chatButtons) > 0 {
			p.chatButtons[0].SetActive(true)
		}

		p.initialized = true
	}

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

func (p *Page) chatHistory(gtx layout.Context, th *material.Theme) layout.Widget {
	utils.ColorBox(gtx, colors.SurfaceContainerLow)
	chats, err := p.client.GetContactChatHistory(p.selectedChat)

	if err != nil {
		return func(gtx layout.Context) layout.Dimensions {
			return layout.Center.Layout(gtx, material.Label(th, 18, "error loading chat history").Layout)
		}
	}

	fmt.Println("chat history: ", chats)

	list := layout.List{Axis: layout.Vertical}

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
								Bottom: 30,
							}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
								gtx.Constraints.Max.Y = 60

								return material.Label(th, 18, string(chats[index].PlainMessage)).Layout(gtx)
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
