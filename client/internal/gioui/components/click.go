package components

import (
	"gioui.org/io/event"
	"gioui.org/io/input"
	"gioui.org/io/pointer"
	"gioui.org/op"
)

type Click struct {
	onClick func()
	pressed bool
	hovered bool
}

func (c *Click) Add(ops *op.Ops) {
	event.Op(ops, c)
}

func (c *Click) Update(q input.Source) {
	for {
		ev, ok := q.Event(pointer.Filter{
			Target: c,
			Kinds:  pointer.Press | pointer.Release | pointer.Enter | pointer.Leave,
		})
		if !ok {
			break
		}

		e, ok := ev.(pointer.Event)
		if !ok {
			continue
		}

		switch e.Kind {
		case pointer.Press:
			c.pressed = true
		case pointer.Release:
			c.pressed = false

			if c.onClick != nil {
				c.onClick()
			}
		case pointer.Enter:
			c.hovered = true
		case pointer.Leave:
			c.hovered = false
		}
	}
}
