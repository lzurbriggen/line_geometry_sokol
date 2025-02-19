# Generate and render mesh data for mitered lines using Sokol

![](./screenshot.png)

This is the code for the [blog post](https://wilg.re/posts/line_geometry/).

The interesting bits are in `line_geometry.odin`. `main.odin` is just an adapted `sokol-odin` example.

## Run

1. `git submodule update --init` to make sure the dependencies are cloned
2. Build Sokol as instructed in `vendor/sokol-odin/README.md`
3. `odin run .`

## Recompile shader

This is for Windows, change the path to call the right executable for your platform:

```sh
./vendor/sokol-tools-bin/bin/win32/sokol-shdc --input shader.glsl --output shader.odin --slang glsl430:hlsl5:metal_macos -f sokol_odin
```
