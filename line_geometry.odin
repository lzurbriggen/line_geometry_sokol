package main

import "./vendor/sokol-odin/sokol/gfx"
import "core:math/linalg"

Line :: struct {
	pts:       []Vec2,
	color:     gfx.Color,
	thickness: f32,
	closed:    bool,
}

wrap_idx := proc(idx, len: int) -> int {
	return (idx % len + len) % len
}

apply_line_geometry :: proc(
	line: Line,
	verts: ^[VERT_BUFFER_SIZE]Vert,
	verts_len: ^int,
	idxs: ^[IDX_BUFFER_SIZE][3]u16,
	idxs_len: ^int,
) {
	pts_len := len(line.pts)
	color := [4]f32{line.color.r, line.color.g, line.color.b, line.color.a}
	if pts_len < 2 {
		return
	}

	idx_0 := u16(verts_len^)
	for i in 0 ..< pts_len {
		half_thickness := line.thickness / 2

		idx_a := wrap_idx(i - 1, pts_len)
		idx_b := i
		idx_c := wrap_idx(i + 1, pts_len)
		a := line.pts[idx_a]
		b := line.pts[idx_b]
		c := line.pts[idx_c]

		dirAB := linalg.normalize(b - a)
		dirBC := linalg.normalize(c - b)
		normalAB := Vec2{-dirAB.y, dirAB.x}
		normalBC := Vec2{-dirBC.y, dirBC.x}

		m0, m1: Vec2
		// if the line should not be closed and we are at the beginning
		// or end of the line, we don't calculate miters
		if !line.closed && (i == 0 || i == pts_len - 1) {
			normal := normalAB
			if i == 0 {
				normal = normalBC
			}
			m0 = b + normal * half_thickness
			m1 = b - normal * half_thickness
		} else {
			// get the miter direction using the normals of both segments
			miter_dir := linalg.normalize(normalBC + normalAB)
			// project onto the normal to get the length
			length := half_thickness / linalg.dot(miter_dir, normalAB)

			m0 = b + miter_dir * length
			m1 = b - miter_dir * length
		}

		buffer_append(verts, verts_len, Vert{pos = m0, color = color})
		buffer_append(verts, verts_len, Vert{pos = m1, color = color})
	}

	num_verts := u16(pts_len) * 2
	last_idx := idx_0 + num_verts - 4
	if line.closed {
		last_idx += 2
	}
	for i := idx_0; i <= last_idx; i += 2 {
		idx_a := i
		idx_b := i + 1
		idx_c := i + 2
		idx_d := i + 3
		if line.closed && idx_a == last_idx {
			idx_c = idx_0
			idx_d = idx_0 + 1
		}
		buffer_append(idxs, idxs_len, [3]u16{idx_a, idx_b, idx_c})
		buffer_append(idxs, idxs_len, [3]u16{idx_b, idx_d, idx_c})
	}
}
