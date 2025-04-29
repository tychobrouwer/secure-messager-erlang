package login

import (
	"client-go/internal/client"
	page "client-go/internal/gioui/pages"

	"gioui.org/layout"
	"gioui.org/widget/material"
)

type Page struct {
	*page.Router
	client *client.Client
}

func New(r *page.Router, c *client.Client) *Page {
	return &Page{
		Router: r,
		client: c,
	}
}

var _ page.Page = &Page{}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	return layout.Dimensions{}
}
