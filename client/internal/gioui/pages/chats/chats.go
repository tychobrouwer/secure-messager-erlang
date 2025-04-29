package chats

import (
	"client-go/internal/client"
	"client-go/internal/gioui/components"
	"client-go/internal/gioui/icons"
	page "client-go/internal/gioui/pages"
	"image"
	"image/color"

	"gioui.org/layout"
	"gioui.org/widget/material"
)

type Page struct {
	*page.Router
	client *client.Client
	split  *components.Split
}

func New(r *page.Router, c *client.Client) *Page {
	return &Page{
		Router: r,
		client: c,
		split:  components.NewSplit(0.25, 0.18, 0.5, 5),
	}
}

var _ page.Page = &Page{}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	p.split.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		return layout.Flex{Axis: layout.Vertical}.Layout(gtx,
			layout.Rigid(
				func(gtx layout.Context) layout.Dimensions {
					return p.chatHeader(th)(gtx)
				},
			),
			layout.Flexed(1,
				func(gtx layout.Context) layout.Dimensions {
					return p.chatList(th)(gtx)
				},
			),
			// return layout.Dimensions{}
		)

	}, func(gtx layout.Context) layout.Dimensions {
		return components.FillWithLabel(gtx, th, "Right", color.NRGBA{R: 0x00, G: 0x00, B: 0xFF, A: 0xFF})
	})

	return layout.Dimensions{Size: gtx.Constraints.Max}
}

func (p *Page) chatList(th *material.Theme) layout.Widget {
	chats := p.client.GetContactIDs()

	list := layout.List{Axis: layout.Vertical}

	return func(gtx layout.Context) layout.Dimensions {
		return list.Layout(gtx, len(chats), func(gtx layout.Context, index int) layout.Dimensions {
			return layout.Flex{Axis: layout.Horizontal}.Layout(gtx,
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return components.FillWithLabel(gtx, th, string(chats[index]), color.NRGBA{R: 0x00, G: 0x00, B: 0xFF, A: 0xFF})
					},
				),
			)
		})
	}
}

func (p *Page) chatHeader(th *material.Theme) layout.Widget {
	return func(gtx layout.Context) layout.Dimensions {
		return layout.Inset{
			Top:    5,
			Bottom: 5,
			Left:   10,
			Right:  10,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return layout.Flex{
				Axis:      layout.Horizontal,
				Alignment: layout.Middle,
			}.Layout(gtx,
				layout.Flexed(1,
					func(gtx layout.Context) layout.Dimensions {
						return material.H5(th, "Chats").Layout(gtx)
					},
				),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						icons.DrawIcon(gtx.Ops, icons.SettingsIcon, 24)
						return layout.Dimensions{Size: image.Pt(24, 24)}
					},
				),
			)
		})
	}
}
