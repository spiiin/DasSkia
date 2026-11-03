# Frame availability, resize and WebGL restoration

Native and web use the same functions. Owned windows expose
`prepare_frame(window): Result<bool, SkiaError>` and
`window_context_generation(window): uint`. Existing dasSDL3 windows expose
`prepare_sdl_frame(target)` and `sdl_context_generation(target)`.

Call preparation after polling application events and before drawing:

```das
let ready = prepare_frame(window)
if (is_err(ready)) {
    let e = unwrap_err(ready)
    print("{e.operation}: {e.message}\n")
    return -1
}
if (!unwrap(ready)) { return 0 } // keep the app loop alive; no draw or swap
let generation = window_context_generation(window)
// If generation changed, recreate any application-owned GPU resources here.
let result = window |> with_frame() $(canvas : SkCanvas?) {
    canvas |> clear(0xff181c28u)
    return skia_ok()
}
```

The existing [window example](../examples/window.das) and
[dasSDL3 example](../examples/sdl_interop.das) show the full lifecycle. All window
galleries now prepare before their frame. For interop, use prepare_sdl_frame and
with_sdl_frame, then let the host call SDL_GL_SwapWindow only for a drawn frame.
Preparation never polls, swaps, destroys or replaces the host's SDL handles.

## Meaning and lifetime

- Ok(true): the window is drawable and Ganesh is available.
- Ok(false): temporarily unavailable because it is minimized, has zero drawable
  pixels, or its WebGL context is lost. Do not draw or swap; poll events again on
  the next app callback. Native preparation yields 16 ms for minimized/zero-size
  windows to avoid an idle spin. Web preparation never blocks the browser thread.
- Err: a real SDL/GL/Ganesh preparation failure, which the application handles.

Raw adapters use -1/0/1 for error/unavailable/ready. Raw BeginFrame/BeginSDLFrame
still report errors if used on an unavailable target; existing with_frame and
with_sdl_frame preserve body errors and their Result payloads. Skipping a frame
is explicit and does not manufacture a successful drawing result.

Preparing or beginning a frame may invalidate its previous borrowed Canvas.
Never retain Canvas aliases across callbacks, resize, pause or context recovery.
Resize rebuilds the surface using drawable pixels, without replacing the SDL GL
context or increasing its generation. Native hidden windows remain drawable for
offscreen tests; hidden is distinct from minimized.

Generation starts at 1 after successful Ganesh creation and increases after
successful context rebuilding. Query it after Ok(true). It does not increase
merely because a loss event arrived or rebuilding failed. This lets applications
recreate context-specific snapshots/textures from retained CPU data. Raster
images, file-backed fonts, shaped text, paragraphs and CPU-backed effects in the
bundled examples remain reusable. GPU-backed images/surface snapshots from the
abandoned context are not automatically restored; applications own that policy.

## Web behavior

The binding installs reference-counted context-loss listeners on the actual SDL
WebGL context. They prevent default loss handling so the browser may restore the
context, coexist with host DOM handlers, and are removed on target destruction.
An event generation catches loss/restoration even if no WASM frame ran while the
context was lost. Skia abandons old Ganesh state before releasing GPU surfaces,
then lazily recreates Ganesh, the interface and framebuffer wrapper after the
browser restores the existing context. It does not recreate the SDL window or
context and does not force the browser to restore a context it cannot restore.

The supplied page reports pause/restoration. Embedding hosts do not need its log
handler for recovery; the binding itself observes loss. Browsers normally defer
loss/restored events between synchronous WASM calls. If the driver loses a
context during an active frame, raw begin/present/end can still return an error;
finish that frame's error handling and retry preparation on a later callback.
There is no rollback of already issued commands or automatic recovery from an
arbitrary native GL driver reset.

For CSS-controlled browser resize, set canvas width and height through CSS before
SDL creates its window. SDL detects external CSS sizing at creation and handles
browser resize events; retain border/padding on a wrapper, not on the canvas.
An embedding host may set zero CSS size while unavailable, then restore it.

## Verification

`window_lifecycle_native` CTest checks native minimize/restore, surface recreation,
resize, generation preservation and exact post-resize pixels. The full native
and strict AOT suites cover existing behavior.

```powershell
python tools/test_web_lifecycle.py --url http://127.0.0.1:8100 --sdl-interop
python tools/test_web_lifecycle.py --url http://127.0.0.1:8099 --strict-aot --sdl-interop
```

Add `--browser firefox --executable <firefox.exe>` to select Firefox. Omit
--sdl-interop for a core-only build. The test exercises owned and borrowed windows,
three real WEBGL_lose_context loss/restoration cycles (one between paused WASM
frames), retained host handlers, zero-size pause, resize pixels, Escape shutdown
and observer cleanup. Strict runs require AOT init/frame/quit markers.
