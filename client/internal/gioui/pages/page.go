package page

import (
	"gioui.org/layout"
	"gioui.org/widget/material"
)

type Page interface {
	Layout(gtx layout.Context, th *material.Theme) layout.Dimensions
}

type Router struct {
	pages   map[any]Page
	current any
}

func NewRouter() *Router {
	return &Router{
		pages:   make(map[any]Page),
		current: nil,
	}
}

func (r *Router) Register(tag any, p Page) {
	r.pages[tag] = p

	if r.current == nil {
		r.current = tag
	}
}

func (r *Router) SetCurrent(tag any) {
	if _, ok := r.pages[tag]; !ok {
		return
	}

	r.current = tag
}

func (r *Router) Layout(gtx layout.Context, th *material.Theme) layout.Dimensions {
	if page, ok := r.pages[r.current]; ok {
		return page.Layout(gtx, th)
	}

	return layout.Dimensions{}
}
