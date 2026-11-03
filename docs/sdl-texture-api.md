# Skia raster → existing dasSDL3 SDL_Renderer

Enable the existing optional integration on both native and web:
`-DDASSKIA_WITH_DASSDL3=ON "-DDASSKIA_DASSDL3_ROOT=$PWD/third_party/dasSDL3"`.
Use `require dasskia/skia_sdl_texture`. One shared C++ implementation backs both
profiles; the same script works with the pinned native and web dasSDL3 modules.
This path uses CPU rasterization and texture upload. SDL_Renderer may itself use
a GPU backend; no Skia Ganesh context or shared GL framebuffer is required.

## API

| Script function | Result / ownership |
| --- | --- |
| create_sdl_texture(renderer, size) | Result<SkiaSDLTexture?>; owns its texture, borrows renderer |
| destroy_sdl_texture(texture) | Releases texture/adapter; never destroys renderer |
| sdl_texture(texture) | Borrowed SDL_Texture? for normal dasSDL3 render/configuration calls |
| sdl_texture_size(texture) | Result<int2>, dimensions in texture pixels |
| resize_sdl_texture(texture, size) | SkiaStatus; same size preserves the existing texture |
| upload_sdl_texture(texture, surface) | SkiaStatus; requires a matching CPU raster surface |
| with_sdl_texture(renderer, size, block) | Synchronous Result scope, destroys adapter after block |

Typical use inside a host-owned renderer lifecycle:

```das
require dasskia/skia_sdl_texture
require dasskia/skia_scope

// renderer already exists and stays owned by the application.
return skia_scope() {
    let surface : SkSurface? = with_raster_surface(
        RasterSurfaceOptions(size=int2(640,480))) |> skia_use
    let texture : SkiaSDLTexture? = renderer |> with_sdl_texture(int2(640,480)) |> skia_use
    canvas(surface) |> clear(0xff39b5f0u)
    texture |> upload_sdl_texture(surface) |> skia_try
    sdl_status(SDL_RenderTexture(renderer,sdl_texture(texture),null,null),
        "SDL_RenderTexture") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderPresent(renderer),"SDL_RenderPresent") |> skia_from_sdl() |> skia_try
    return skia_ok()
}
```

The application also polls events, configures its renderer, clears the destination
and chooses source/destination rectangles. The adapter never polls, renders or
presents. For persistent frame callbacks, use create/destroy as demonstrated by
[examples/sdl_texture.das](../examples/sdl_texture.das): raster text and shapes,
transparent composition over the SDL background, resize, zero-size/minimized
pause, and Escape/close cleanup. Existing frame/paragraph APIs are unchanged.

## Pixels, resize and lifetime

Skia raster surfaces store premultiplied pixels. Upload converts them to byte
RGBA with straight alpha, matching SDL_PIXELFORMAT_RGBA32 and SDL_BLENDMODE_BLEND.
Conversion writes directly into the locked streaming texture using SDL's actual
pitch, while Skia respects the source rowBytes. There is no script array or
retained source pointer. The surface can be released after a successful upload.
No implicit GPU readback is performed: surfaces whose pixels cannot be peeked
are rejected. Source and texture dimensions must match exactly.

Textures default to nearest filtering and standard alpha blending. They start
transparent black, including after a size change. The borrowed SDL_Texture can
be configured through existing dasSDL3 texture functions, but remains owned by
the adapter: do not destroy it separately or retain it across resize/destruction.

Resize first creates a replacement. Failure preserves the old texture and its
contents; a successful size change invalidates the borrowed SDL_Texture pointer
and clears the replacement. Resize does not resize the source surface, renderer
or SDL window. Create a matching raster surface in the host; the example allocates
that first, resizes the texture, then replaces its previous surface. Dimensions
must be in 1..16384 and within the SDL backend's own texture limits.

Release adapter textures before SDL_DestroyRenderer (which also destroys its
textures), and release renderer before its window/SDL shutdown. Source surfaces
remain owned separately. Scope cleanup covers normal/early Result returns, and
preserves a body Err. Scopes do not protect escaped pointers or arbitrary panics.
All renderer/texture operations obey SDL's main-thread and renderer-affinity rules.

This is a full texture upload each call, with CPU rasterization and alpha
conversion costs. There is no dirty-rectangle transfer, shared GPU memory or
zero-copy promise. Caller GPU/renderer reset policy remains explicit: recreate
the texture adapter when SDL requires texture recreation, then upload the retained
raster data again. This adapter does not add a second WebGL context-loss owner to
an SDL_Renderer backend or automatically recover its device.

## Run and strict AOT

```powershell
build/desktop/bin/dasSkia_runner.exe examples/sdl_texture.das
build/desktop/bin/dasSkia_aot_runner.exe examples/sdl_texture.das
ctest --test-dir build/desktop -R sdl_texture --output-on-failure
```

Both AOT inventories include the script helper, pixel test and example, plus the
existing imported sdl3_result helper. For wasm32 strict AOT build/serve instructions,
see [web-aot.md](web-aot.md). Open `?script=/examples/sdl_texture.das` on either
site. The page also has a Raster to SDL_Texture link when interop is enabled.

`tools/test_web.py --sdl-interop` checks script pixels and the example; add
`--strict-aot` on the strict site. `tools/test_web_sdl_texture.py` additionally
checks browser resize to 640x480, zero CSS size, return to 900x600, post-upload
alpha pixels and actual Escape cancellation. It accepts --url, --browser,
--executable and --strict-aot, like the other browser checks.

The native software-renderer test uses deliberately padded raster rows and checks
opaque/transparent/translucent output, renderer state and borrowed lifetime.
The script test covers the selected renderer, failure-preserving resize, same-size
resize, dimension mismatch, null inputs, scope cleanup and primary body errors.
See [VALIDATION.md](../VALIDATION.md) for actual results and tested profiles.

6 additional typed C++ adapters: Skia_NewSDLTexture, Skia_DeleteSDLTexture,
Skia_ResizeSDLTexture, Skia_GetSDLTexture, Skia_SDLTextureSize and
Skia_UploadSDLTexture. The core is 301; optional dasSDL3 interop is 15,
for **316 adapters together**. These adapters are not a stable C ABI.
