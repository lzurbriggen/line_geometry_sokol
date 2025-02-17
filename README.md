## Run

1. Build sokol as instructed in `sokol/README.md`
2. `odin run ./`

## Recompile shader

This is for Windows, change the path to call the right bin for your platform:

```sh
./sokol-tools-bin/bin/win32/sokol-shdc --input shader.glsl --output shader.odin --slang glsl430:hlsl5:metal_macos -f sokol_odin
```
