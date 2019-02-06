import "lib/github.com/athas/vector/vspace"

module vec3 = mk_vspace_3d f32

type pixel = i32
type pos3 = vec3.vector
type pos2 = {x: i32, y: i32}
type pos_proj = {x: i32, y: i32, z: f32}
type tri3 = {p0: pos3, p1: pos3, p2: pos3, color: pixel}
type tri_proj = {p0: pos_proj, p1: pos_proj, p2: pos_proj, color: pixel}
type bbox = {upper_left: pos2, lower_right: pos2}
type loc = {color: pixel, z: f32}
type point_barycentric = {factor: i32, a: i32, b: i32, c: i32, an: f32, bn: f32, cn: f32}

let i32min3 x y z = i32.min x (i32.min y z)
let i32max3 x y z = i32.max x (i32.max y z)

let make_bbox (t: tri_proj): bbox =
  {upper_left={x=i32min3 t.p0.x t.p1.x t.p2.x,
               y=i32min3 t.p0.y t.p1.y t.p2.y},
   lower_right={x=i32max3 t.p0.x t.p1.x t.p2.x,
                y=i32max3 t.p0.y t.p1.y t.p2.y}}

let bbox_size (bb: bbox): i32 =
  (bb.lower_right.x - bb.upper_left.x + 1) * (bb.lower_right.y - bb.upper_left.y + 1)

let neutral_loc: loc = {color=0xffffffff, z=f32.inf}

let barycentric_coordinates (p: pos2) (t: tri_proj): point_barycentric =
  let factor = (t.p1.y - t.p2.y) * (t.p0.x - t.p2.x) + (t.p2.x - t.p1.x) * (t.p0.y - t.p2.y)
  in if factor != 0 -- Avoid division by zero.
     then let a = ((t.p1.y - t.p2.y) * (p.x - t.p2.x) + (t.p2.x - t.p1.x) * (p.y - t.p2.y))
          let b = ((t.p2.y - t.p0.y) * (p.x - t.p2.x) + (t.p0.x - t.p2.x) * (p.y - t.p2.y))
          let c = factor - a - b
          let factor' = r32 factor
          let an = r32 a / factor'
          let bn = r32 b / factor'
          let cn = 1.0 - an - bn
          in {factor=factor, a=a, b=b, c=c, an=an, bn=bn, cn=cn}
     else {factor=1, a= -1, b= -1, c= -1, an= -1.0, bn= -1.0, cn= -1.0} -- Don't draw.

let interpolate_z (t: tri_proj) (p: point_barycentric): f32 =
  p.an * t.p0.z + p.bn * t.p1.z + p.cn * t.p2.z

let in_range (t: i32) (a: i32) (b: i32): bool =
  (a < b && a <= t && t <= b) || (b <= a && b <= t && t <= a)

let is_inside_triangle (p: point_barycentric): bool =
  in_range p.a 0 p.factor && in_range p.b 0 p.factor && in_range p.c 0 p.factor

let render_to_rect (w: i32) (output_size: i32) (t: tri_proj): [](i32, loc) =
  let bb = make_bbox t
  let points = unsafe flatten (map (\y -> map (\x -> {y=y, x=x}) (bb.upper_left.x...bb.lower_right.x))
                               (bb.upper_left.y...bb.lower_right.y))
  let empty_draw = (-1, neutral_loc)
  let draws = map (\p -> let bary = barycentric_coordinates p t
                         in if is_inside_triangle bary
                            then let index = p.y * w + p.x
                                 let z = interpolate_z t bary
                                 in (index, {color=t.color, z=z})
                            else empty_draw) points
  in draws ++ unsafe replicate (output_size - bbox_size bb) empty_draw -- Ensure regularity

let split_triangle (t: tri3): (tri3, tri3) =
  let p_middle = t.p1 vec3.+ vec3.scale 0.5 (t.p2 vec3.- t.p1)
  -- "Rotate" the points to ensure that a good split will happen at some point.
  let t0 = {p1=t.p0, p2=t.p1, p0=p_middle, color=t.color}
  let t1 = {p1=t.p0, p2=p_middle, p0=t.p2, color=t.color}
  in (t0, t1)

-- Dummy value to ensure array regularity.
let empty_triangle: tri3 = {p0={x=0, y=0, z=0},
                            p1={x=0, y=0, z=0},
                            p2={x=0, y=0, z=0},
                            color=0}

-- Should be both associative and commutative.
let merge_locs (loc0: loc) (loc1: loc): loc =
  if loc0.z < loc1.z && loc0.z >= 0.0
  then loc0
  else loc1

let project_point (view_dist: f32) (p: pos3): pos_proj =
  let z_ratio = if p.z >= 0.0
                then (view_dist + p.z) / view_dist
                else 1.0 / ((view_dist - p.z) / view_dist)
  let x_projected = p.x / z_ratio
  let y_projected = p.y / z_ratio
  in {x=t32 x_projected, y=t32 y_projected, z=p.z}

let project_triangle (view_dist: f32) (t: tri3): tri_proj =
  {p0=project_point view_dist t.p0,
   p1=project_point view_dist t.p1,
   p2=project_point view_dist t.p2,
   color=t.color}

let render_triangles (h: i32) (w: i32) (bbox_max_size: i32) (view_dist: f32) (ts: []tri3): [h][w]pixel =
  let (_, ts', _) = loop (ts, ts_projected, some_triangles_too_large) =
                      (ts, map (project_triangle view_dist) ts, true)
                    while some_triangles_too_large do
    let (size_checks, ts') = unzip (map2 (\t tp -> if bbox_size (make_bbox tp) > bbox_max_size
                                                   then (true, split_triangle t)
                                                   else (false, (t, empty_triangle))) ts ts_projected)
    in if or size_checks
       then let ts'' = map2 (\is_split (t0, t1) -> [(true, t0), (is_split, t1)]) size_checks ts'
            let ts''' = map (\(_, p) -> p) (filter (\(is_split, _) -> is_split) (flatten ts''))
            let ts_projected' = map (project_triangle view_dist) ts'''
            in (ts''', ts_projected', true)
       else (ts, ts_projected, false)
  let frame = replicate (w * h) neutral_loc
  let (is, as) = unzip (unsafe flatten (map (render_to_rect w bbox_max_size) ts'))
  let frame' = reduce_by_index frame merge_locs neutral_loc is as
  in unflatten h w (map (\loc -> loc.color) frame')
