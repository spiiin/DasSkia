# Ownership, errors and rendering lifecycle

- Surface and Image factories return owned references; release with their unref adapters.
- Paint and Path use delete. A surface's Canvas is borrowed and must never be deleted.
- `with_*` blocks lend resources synchronously. Do not retain, return or manually destroy
  their pointers. `Result` itself does not own a pointer; scopes are not unique ownership.
- `skia_use` needs an explicit pointer type and a direct binding in `skia_scope`.
- `with_saved` restores the original save count, including on a body Err.
- Deferred cleanup covers normal and early returns, not arbitrary script panic.
- Raw calls require live, correctly owned pointers. They retain native preconditions.
- Skia has no universal SDL_GetError equivalent. Core errors use operation-specific
  messages; SDL adapter errors copy available SDL diagnostics before cleanup.
- Paint allocation and fatal out-of-memory behavior follow native C++/Skia behavior;
  no exception-to-Result allocation guarantee is added.

## SDL and browser lifecycle

The SDL adapter owns its window, GL context and Skia context. It is intended for
main-thread use and does not share the context with external GL code or SDL_Renderer.
Its event helper is for one-window examples and consumes the SDL event queue.
Resize rewraps the framebuffer using its pixel dimensions. Surface Canvas pointers
must not survive a resize/frame-target replacement. Call `prepare_frame` /
`prepare_sdl_frame` before drawing: `Ok(false)` skips a
minimized, zero-size or temporarily lost target without terminating the app loop.

Use `with_window` for a synchronous lifetime, or `create_window` / `destroy_window`
in app_init/app_quit for browser frame callbacks. `with_frame` presents only on Ok;
on body Err it returns the body error without presenting. There is no rollback of
already recorded drawing commands. The caller should stop or explicitly reset state.

WebGL loss pauses prepared frames; restoration lazily rebuilds Ganesh without
reloading the page. Context generations let applications recreate their own GPU
resources. See [frame lifecycle and restoration](window-lifecycle.md).
Browser assets must be preloaded into the
Emscripten filesystem or supplied by a host loader. Native file paths and fonts do
not become browser assets automatically.

Keep CSS layout borders/padding on a canvas wrapper; the supplied canvas uses
outline. SDL's CSS-size detection otherwise mistakes a border-expanded 1x1 probe
for externally controlled dimensions. Tests keep the browser canvas visible;
`SKIA_WEB` is available for small platform-specific choices.

See [testing and support](../VALIDATION.md) for actual tested configurations and limits.

## Raster values

Rectangles use `(x,y,width,height)`. Packed colors and copied pixels use numeric
unpremultiplied ARGB, independent of native byte order. Raster surfaces use
RGBA8888 premultiplied alpha with an untagged color space. Dimensions are limited
to 1..16384 per axis; this does not guarantee allocation success.
