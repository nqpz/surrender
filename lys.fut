import "lib/github.com/diku-dk/lys/lys"
import "surrender"

module lys: lys = {
  type state = {h: i32, w: i32,
                triangles: []tri3}

  let init (h: i32) (w: i32): state =
    {w, h,
     triangles=[ { p0={x=310, y=0, z=500}
                 , p1={x=800, y=800, z=400}
                 , p2={x=320, y=800, z=300}
                 , color=0xff0000ff
                 }
               , { p0={x=100, y=150, z=550}
                 , p1={x=600, y=440, z=430}
                 , p2={x=120, y=400, z=300}
                 , color=0xffff0000
                 }
               ]}

  let resize (h: i32) (w: i32) (s: state) =
    s with h = h with w = w

  let key _ _ s = s
  let mouse _ _ _ s = s
  let wheel _ _ s = s
  let step _ s = s

  let render (s: state) =
    render_triangles s.h s.w 1000 600 s.triangles
}
