package components

import (
	"image"

	"gioui.org/io/event"
	"gioui.org/io/pointer"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/clip"
	"gioui.org/unit"
)

type SplitStyle struct {
	ratio    float32
	min      float32
	max      float32
	minPixel int
	maxPixel int
	bar      unit.Dp

	drag   bool
	dragID pointer.ID
	dragX  float32
}

const defaultBarWidth = unit.Dp(10)

func Split(ratio, min, max float32, minPixel, maxPixel int, bar unit.Dp) *SplitStyle {
	if bar <= 0 {
		bar = defaultBarWidth
	}

	return &SplitStyle{
		ratio:    ratio,
		min:      min,
		max:      max,
		minPixel: minPixel,
		maxPixel: maxPixel,
		bar:      bar,
	}
}

func (s *SplitStyle) Layout(gtx layout.Context, left, right layout.Widget) layout.Dimensions {
	bar := gtx.Dp(s.bar)
	if bar <= 1 {
		bar = gtx.Dp(defaultBarWidth)
	}

	leftsize := int(s.ratio*float32(gtx.Constraints.Max.X) - float32(bar))

	rightoffset := leftsize + bar
	rightsize := gtx.Constraints.Max.X - rightoffset

	{
		barRect := image.Rect(leftsize, 0, rightoffset, gtx.Constraints.Max.Y)
		area := clip.Rect(barRect).Push(gtx.Ops)

		event.Op(gtx.Ops, s)
		pointer.CursorColResize.Add(gtx.Ops)

		for {
			ev, ok := gtx.Event(pointer.Filter{
				Target: s,
				Kinds:  pointer.Press | pointer.Drag | pointer.Release | pointer.Cancel,
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
				if s.drag {
					break
				}

				s.dragID = e.PointerID
				s.dragX = e.Position.X
				s.drag = true

			case pointer.Drag:
				if s.dragID != e.PointerID {
					break
				}

				deltaX := e.Position.X - s.dragX
				deltaRatio := deltaX / float32(gtx.Constraints.Max.X)

				if s.ratio+deltaRatio < s.min || s.ratio+deltaRatio > s.max {
					break
				}

				if deltaRatio < 0 && leftsize <= s.minPixel {
					break
				} else if deltaRatio > 0 && leftsize >= s.maxPixel {
					break
				}

				s.dragX = e.Position.X
				s.ratio += deltaRatio

				if e.Priority < pointer.Grabbed {
					gtx.Execute(pointer.GrabCmd{
						Tag: s,
						ID:  s.dragID,
					})
				}

			case pointer.Release:
				fallthrough
			case pointer.Cancel:
				s.drag = false
			}
		}

		area.Pop()
	}

	{
		gtx := gtx
		gtx.Constraints = layout.Exact(image.Pt(leftsize, gtx.Constraints.Max.Y))
		left(gtx)
	}

	{
		off := op.Offset(image.Pt(rightoffset, 0)).Push(gtx.Ops)
		gtx := gtx
		gtx.Constraints = layout.Exact(image.Pt(rightsize, gtx.Constraints.Max.Y))
		right(gtx)
		off.Pop()
	}

	return layout.Dimensions{Size: gtx.Constraints.Max}
}
