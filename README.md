## Run

1. `git submodule update --init` to make sure the dependencies are cloned
2. Build sokol as instructed in `vendor/sokol/README.md`
3. `odin run ./`

## Recompile shader

This is for Windows, change the path to call the right bin for your platform:

```sh
./vendor/sokol-tools-bin/bin/win32/sokol-shdc --input shader.glsl --output shader.odin --slang glsl430:hlsl5:metal_macos -f sokol_odin
```
