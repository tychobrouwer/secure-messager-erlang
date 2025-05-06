package gioui

import (
	"client-go/internal/client"
	page "client-go/internal/gioui/pages"
	"client-go/internal/gioui/pages/chats"
	"client-go/internal/gioui/pages/loading"
	"client-go/internal/gioui/pages/login"
	"log"
	"os"

	"gioui.org/app"
	"gioui.org/op"
	"gioui.org/widget/material"
)

type App struct {
	window *app.Window
}

func NewApp() *App {
	// Create a new window with a title and size.
	window := new(app.Window)

	app := &App{
		window: window,
	}

	return app
}

func (a *App) Loop(c *client.Client) error {
	var ops op.Ops

	th := material.NewTheme()

	router := page.NewRouter()
	router.Register("loading", loading.New(router, c))
	router.Register("login", login.New(router, c))
	router.Register("chats", chats.New(router, c))

	for {
		switch e := a.window.Event().(type) {
		case app.DestroyEvent:
			if e.Err != nil {
				log.Fatal(e.Err)
			}

			os.Exit(0)

		case app.FrameEvent:
			// This graphics context is used for managing the rendering state.
			gtx := app.NewContext(&ops, e)

			// Chats layout
			router.Layout(gtx, th)

			// Pass the drawing operations to the GPU.
			e.Frame(gtx.Ops)
		}
	}
}
