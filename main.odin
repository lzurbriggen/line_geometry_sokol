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

Vert :: struct {
	pos:   [2]f32,
	color: [4]f32,
}

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
			pts = {{50, 0}, {100, 50}, {200, 50}, {200, -100}, {30, -50}},
			thickness = 20,
			color = {1, 1, 1, 1},
		},
		&verts,
		&verts_len,
		&tri_idxs,
		&state.tri_idxs_len,
	)
	offset_x :: -250
	apply_line_geometry(
		{
			pts = {
				{offset_x + 50, 0},
				{offset_x + 100, 50},
				{offset_x + 200, 50},
				{offset_x + 200, -100},
				{offset_x + 30, -50},
			},
			thickness = 20,
			color = {1, 1, 1, 1},
			closed = true,
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

buffer_append :: proc(buf: ^[$N]$T, buf_len: ^int, element: T) {
	buf[buf_len^] = element
	buf_len^ += 1
}
