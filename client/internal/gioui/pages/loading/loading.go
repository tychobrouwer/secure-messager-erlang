package loading

import (
	"client-go/internal/client"
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/icons"
	page "client-go/internal/gioui/pages"
	"client-go/internal/gioui/utils"
	"client-go/internal/sqlite"
	"fmt"
	"image"
	"log"
	"time"

	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/widget/material"
)

type Page struct {
	*page.Router
	client    *client.Client
	startTime int64
}

func New(r *page.Router, c *client.Client) *Page {
	page := &Page{
		Router:    r,
		client:    c,
		startTime: time.Now().UnixMilli(),
	}

	go page.init()

	return page
}

func (p *Page) init() {
	fmt.Println("Connecting to server...")

	err := p.client.TCPServer.Connect()

	if err != nil {
		log.Fatalf("Failed to connect to server: %v", err)
	}

	fmt.Println("Loading client data...")

	err = p.client.LoadClientData()

	if err != nil {
		log.Fatalf("Failed to load client data: %v", err)
	}

	userID, password, err := sqlite.GetLoginData(p.client.DB)

	if err != nil {
		fmt.Println("Signing up...")

		userID := []byte("test7")
		password := []byte("password")

		err := p.client.Signup(userID, password)
		if err != nil {
			log.Fatalf("Signup failed: %v", err)
		}
	} else {
		fmt.Println("Logging in...")

		err = p.client.Login(userID, password)
		if err != nil {
			log.Fatalf("Login failed: %v", err)
		}
	}

	p.Router.SetCurrent("login")
}

var _ page.Page = &Page{}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	utils.ColorBox(gtx, colors.Surface)

	layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		timeDiff := time.Now().UnixMilli() - p.startTime
		angle := float32(timeDiff/4%360) * 3.14 / 180

		gtx.Execute(op.InvalidateCmd{})

		icons.DrawIcon(gtx.Ops, icons.Loader, colors.OnSurface, 50, angle)
		return layout.Dimensions{Size: image.Pt(50, 50)}
	})

	return layout.Dimensions{}
}
