package main

import sapp "./vendor/sokol-odin/sokol/app"
import "./vendor/sokol-odin/sokol/gfx"
import sglue "./vendor/sokol-odin/sokol/glue"
import slog "./vendor/sokol-odin/sokol/log"
import "base:runtime"
import "core:fmt"
import "core:math/linalg"

VERT_BUFFER_SIZE :: 1000
IDX_BUFFER_SIZE :: 1000

Vec2 :: [2]f32
Mat4 :: matrix[4, 4]f32

state: struct {
	pass_action:  gfx.Pass_Action,
	pip:          gfx.Pipeline,
	bind:         gfx.Bindings,
	tri_idxs_len: int,
}

init :: proc "c" () {
	context = runtime.default_context()

	gfx.setup({environment = sglue.environment(), logger = {func = slog.func}})

	verts := [VERT_BUFFER_SIZE]Vert{}
	verts_len := 0
	tri_idxs := [IDX_BUFFER_SIZE][3]u16{}
	apply_line_geometry(
		{
			pts = {{0, 0}, {50, 50}, {150, 50}, {150, -100}, {-150, -50}},
			thickness = 20,
			color = {1, 1, 1, 1},
			closed = false,
		},
		&verts,
		&verts_len,
		&tri_idxs,
		&state.tri_idxs_len,
	)
	state.bind.vertex_buffers[0] = gfx.make_buffer({data = {ptr = &verts, size = size_of(verts)}})

	state.bind.index_buffer = gfx.make_buffer(
		{type = .INDEXBUFFER, data = {ptr = &tri_idxs, size = size_of(tri_idxs)}},
	)

	state.pip = gfx.make_pipeline(
		{
			shader = gfx.make_shader(line_shader_desc(gfx.query_backend())),
			index_type = .UINT16,
			layout = {
				attrs = {
					ATTR_line_pos = {format = .FLOAT2, buffer_index = 0},
					ATTR_line_color0 = {format = .FLOAT4, buffer_index = 0},
				},
			},
			depth = {compare = .LESS_EQUAL, write_enabled = true},
		},
	)

	state.pass_action = {
		colors = {0 = {load_action = .CLEAR, clear_value = {0, 0, 1, 1}}},
	}
}

frame :: proc "c" () {
	context = runtime.default_context()
	gfx.begin_pass({action = state.pass_action, swapchain = sglue.swapchain()})
	gfx.apply_pipeline(state.pip)
	gfx.apply_bindings(state.bind)
	proj := linalg.matrix_ortho3d_f32(
		-sapp.widthf() / 2,
		sapp.widthf() / 2,
		sapp.heightf() / 2,
		-sapp.heightf() / 2,
		-1,
		1,
		false,
	)
	vs_params := Vs_Params {
		transform = proj,
	}
	gfx.apply_uniforms(UB_vs_params, {ptr = &vs_params, size = size_of(vs_params)})
	// TODO: is this correct?
	gfx.draw(0, state.tri_idxs_len * 3, 1)
	gfx.end_pass()
	gfx.commit()
}

cleanup :: proc "c" () {
	context = runtime.default_context()
	gfx.shutdown()
}

main :: proc() {
	sapp.run(
		{
			init_cb = init,
			frame_cb = frame,
			cleanup_cb = cleanup,
			width = 800,
			height = 600,
			window_title = "Line geometry",
			icon = {sokol_default = true},
			logger = {func = slog.func},
		},
	)
}

Line :: struct {
	pts:       []Vec2,
	color:     gfx.Color,
	thickness: f32,
	closed:    bool,
}

wrap_idx := proc(idx, len: int) -> int {
	return (idx % len + len) % len
}

Vert :: struct {
	pos:   [2]f32,
	color: [4]f32,
}

apply_unclosed_ending_pts :: proc(def: Line, idx_a, idx_b: int) -> [2]Vec2 {
	p0 := def.pts[idx_a]
	p1 := def.pts[idx_b]
	line := p1 - p0
	normal := linalg.normalize(Vec2{-line.y, line.x})
	a := p0 + normal * def.thickness / 2
	b := p0 - normal * def.thickness / 2
	return {a, b}
}

buffer_append :: proc(buf: ^[$N]$T, buf_len: ^int, element: T) {
	buf[buf_len^] = element
	buf_len^ += 1
}

apply_line_geometry :: proc(
	def: Line,
	verts: ^[VERT_BUFFER_SIZE]Vert,
	verts_len: ^int,
	idxs: ^[IDX_BUFFER_SIZE][3]u16,
	idxs_len: ^int,
) {
	pts_len := len(def.pts)

	color := [4]f32{def.color.r, def.color.g, def.color.b, def.color.a}

	if pts_len < 2 {
		return
	}

	start_vert_idx := verts_len^
	for i in 0 ..< pts_len {
		half_thickness := def.thickness / 2

		idx_prev := wrap_idx(i - 1, pts_len)
		idx_0 := i
		idx_1 := wrap_idx(i + 1, pts_len)
		p_prev := def.pts[idx_prev]
		p_0 := def.pts[idx_0]
		p_1 := def.pts[idx_1]

		dir: Vec2
		if !def.closed && i == 0 {
			// for the start points, we need the normal of the second segment instead
			dir = linalg.normalize(p_1 - p_0)
		} else {
			dir = linalg.normalize(p_0 - p_prev)
		}
		normal := Vec2{-dir.y, dir.x}

		m0, m1: Vec2
		// if the line should not be closed and we are at the beginning
		// or end of the line, we don't calculate miters
		if !def.closed && (i == 0 || i == pts_len - 1) {
			m0 = p_0 + normal * half_thickness
			m1 = p_0 - normal * half_thickness
		} else {
			dir2 := linalg.normalize(p_1 - p_0)
			miter_normal := linalg.normalize(dir2 + dir)
			miter_dir := Vec2{-miter_normal.y, miter_normal.x}
			length := half_thickness / linalg.dot(miter_dir, normal)

			m0 = p_0 + miter_dir * length
			m1 = p_0 - miter_dir * length
		}

		buffer_append(verts, verts_len, Vert{pos = m0, color = color})
		buffer_append(verts, verts_len, Vert{pos = m1, color = color})
	}

	vert_len := verts_len^ - start_vert_idx
	for i := 0; i < vert_len; i += 2 {
		// don't connect start- and end vertices if the line should not be closed
		if !def.closed && i >= vert_len - 2 {
			break
		}
		idx_a := u16(start_vert_idx + i)
		idx_b := u16(start_vert_idx + i + 1)
		idx_c := u16(start_vert_idx + wrap_idx(i + 2, vert_len))
		idx_d := u16(start_vert_idx + wrap_idx(i + 3, vert_len))

		buffer_append(idxs, idxs_len, [3]u16{idx_a, idx_b, idx_c})
		buffer_append(idxs, idxs_len, [3]u16{idx_b, idx_d, idx_c})
	}
}
