package login

import (
	"client-go/internal/client"
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/components"
	page "client-go/internal/gioui/pages"
	"client-go/internal/gioui/utils"
	"log"

	"gioui.org/font"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/paint"
	"gioui.org/widget"
	"gioui.org/widget/material"
)

type Page struct {
	*page.Router
	client              *client.Client
	state               int
	usernameInput       *components.InputStyle
	passwordInput       *components.InputStyle
	passwordRepeatInput *components.InputStyle
}

const (
	LoginState = iota
	SignupState
)

func New(r *page.Router, c *client.Client) *Page {
	return &Page{
		Router:              r,
		client:              c,
		state:               LoginState,
		usernameInput:       components.Input("Username"),
		passwordInput:       components.Input("Password"),
		passwordRepeatInput: components.Input("Repeat Password"),
	}
}

var _ page.Page = &Page{}

func (p *Page) UpdateState(state int) {
	p.state = state
}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	utils.ColorBox(gtx, colors.Surface)

	layout.Center.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
		gtx.Constraints.Max.X = 400
		gtx.Constraints.Max.Y = 320

		utils.ColorRoundBox(gtx, colors.SurfaceContainerLowest, 5)

		layout.Inset{
			Top:    5,
			Bottom: 5,
			Left:   80,
			Right:  80,
		}.Layout(gtx, func(gtx layout.Context) layout.Dimensions {
			return layout.Flex{Axis: layout.Vertical, Spacing: 10}.Layout(gtx,
				layout.Rigid(layout.Spacer{Height: 10}.Layout),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return layout.Flex{Axis: layout.Horizontal, Spacing: 10}.Layout(gtx,
							layout.Flexed(0.5, layout.Spacer{}.Layout),
							layout.Rigid(
								func(gtx layout.Context) layout.Dimensions {
									tl := widget.Label{}

									font := font.Font{
										Typeface: th.Face,
									}

									textColorMacro := op.Record(gtx.Ops)
									paint.ColorOp{Color: colors.OnSurface}.Add(gtx.Ops)
									textColorOp := textColorMacro.Stop()

									if p.state == SignupState {
										return tl.Layout(gtx, th.Shaper, font, 24, "Sign Up", textColorOp)
									}
									return tl.Layout(gtx, th.Shaper, font, 24, "Login", textColorOp)
								},
							),
							layout.Flexed(0.5, layout.Spacer{}.Layout),
						)
					},
				),
				layout.Rigid(layout.Spacer{Height: 20}.Layout),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return p.usernameInput.Layout(gtx, th)
					},
				),
				layout.Rigid(layout.Spacer{Height: 10}.Layout),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return p.passwordInput.Layout(gtx, th)
					},
				),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						if p.state == SignupState {
							return layout.Spacer{Height: 10}.Layout(gtx)
						}

						return layout.Spacer{Height: 0}.Layout(gtx)
					},
				),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						if p.state == SignupState {
							return p.passwordRepeatInput.Layout(gtx, th)
						}
						return layout.Spacer{Height: 0}.Layout(gtx)
					},
				),
				layout.Rigid(layout.Spacer{Height: 20}.Layout),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return layout.Flex{Axis: layout.Horizontal, Spacing: 10}.Layout(gtx,
							layout.Flexed(0.5, layout.Spacer{}.Layout),
							layout.Rigid(
								func(gtx layout.Context) layout.Dimensions {
									if p.state == SignupState {
										return components.Button("Sign Up", 150, false, func() {
											userID := p.usernameInput.Editor.Text()
											password := p.passwordInput.Editor.Text()
											passwordRepeat := p.passwordRepeatInput.Editor.Text()

											if password != passwordRepeat {
												log.Printf("Passwords do not match")
												return
											}

											err := p.client.Signup([]byte(userID), []byte(password))
											if err == nil {
												log.Printf("Sign up successful: %s", userID)

												p.Router.SetCurrent("chats")
												return
											}

											log.Printf("Sign up failed: %v", err)
											p.passwordInput.Editor.SetText("")
											p.passwordRepeatInput.Editor.SetText("")
										}).Layout(gtx, th)
									}
									return components.Button("Sign In", 150, false, func() {
										userID := p.usernameInput.Editor.Text()
										password := p.passwordInput.Editor.Text()

										err := p.client.Login([]byte(userID), []byte(password))
										if err == nil {
											log.Printf("Login successful: %s", userID)

											p.Router.SetCurrent("chats")
											return
										}

										log.Printf("Login failed: %v", err)
										p.passwordInput.Editor.SetText("")
									}).Layout(gtx, th)
								},
							),
							layout.Flexed(0.5, layout.Spacer{}.Layout),
						)
					},
				),
				layout.Rigid(layout.Spacer{Height: 20}.Layout),
				layout.Rigid(
					func(gtx layout.Context) layout.Dimensions {
						return layout.Flex{Axis: layout.Horizontal, Spacing: 10}.Layout(gtx,
							layout.Flexed(0.5, layout.Spacer{}.Layout),
							layout.Rigid(
								func(gtx layout.Context) layout.Dimensions {
									font := font.Font{
										Typeface: th.Face,
									}

									textColorMacro := op.Record(gtx.Ops)
									paint.ColorOp{Color: colors.OnSurface}.Add(gtx.Ops)
									textColorOp := textColorMacro.Stop()

									tl := widget.Label{}

									if p.state == SignupState {
										return tl.Layout(gtx, th.Shaper, font, 12, "Already have an account? ", textColorOp)
									}
									return tl.Layout(gtx, th.Shaper, font, 12, "Don't have an account? ", textColorOp)
								},
							),
							layout.Rigid(
								func(gtx layout.Context) layout.Dimensions {
									if p.state == SignupState {
										return components.ButtonLink("Sign In", func() {
											p.UpdateState(LoginState)
										}).Layout(gtx, th)
									}

									return components.ButtonLink("Sign Up", func() {
										p.UpdateState(SignupState)
									}).Layout(gtx, th)
								},
							),
							layout.Flexed(0.5, layout.Spacer{}.Layout),
						)
					},
				),
			)
		})

		return layout.Dimensions{Size: gtx.Constraints.Max}
	})

	return layout.Dimensions{}
}
