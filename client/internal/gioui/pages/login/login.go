package login

import (
	"client-go/internal/client"
	"client-go/internal/gioui/colors"
	"client-go/internal/gioui/components"
	page "client-go/internal/gioui/pages"
	"client-go/internal/gioui/utils"
	"fmt"
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
	state               uint8
	usernameInput       *components.InputStyle
	passwordInput       *components.InputStyle
	passwordRepeatInput *components.InputStyle
	signinButton        components.ClickableButton
	signupButton        components.ClickableButton
	stateSwitchLink     components.ClickableButtonLink
}

const (
	LoginState = iota
	SignupState
)

func New(r *page.Router, c *client.Client) *Page {
	p := &Page{
		Router:              r,
		client:              c,
		state:               LoginState,
		usernameInput:       components.Input("Username", 1),
		passwordInput:       components.Input("Password", 1),
		passwordRepeatInput: components.Input("Repeat Password", 1),
		signinButton:        components.Button("Sign In", 150),
		signupButton:        components.Button("Sign Up", 150),
		stateSwitchLink:     components.ButtonLink("Sign In"),
	}

	p.signinButton.SetOnClick(p.SignIn)
	p.signupButton.SetOnClick(p.Signup)
	p.stateSwitchLink.SetOnClick(func() {
		if p.state == SignupState {
			p.stateSwitchLink.SetTitle("Sign Up")
			p.UpdateState(LoginState)
		} else {
			p.stateSwitchLink.SetTitle("Sign In")
			p.UpdateState(SignupState)
		}
	})

	return p
}

func (p *Page) SignIn() {
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
}

func (p *Page) Signup() {
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
}

var _ page.Page = &Page{}

func (p *Page) UpdateState(state uint8) {
	p.state = state
}

func (p *Page) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	fmt.Println("Login page layout")

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
										return p.signupButton.Layout(gtx, th)
									}
									return p.signinButton.Layout(gtx, th)
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
									return p.stateSwitchLink.Layout(gtx, th)
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
