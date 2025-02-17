@header package main
@header import sg "sokol/sokol/gfx"
@header import m "math"
@ctype mat4 m.mat4

@vs vs
layout(binding=0) uniform vs_params {
    mat4 transform;
};

in vec3 pos;
in vec4 color0;
out vec4 color;

void main() {
    gl_Position = transform * vec4(pos.xyz, 1.0);
    color = color0;
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program line vs fs
