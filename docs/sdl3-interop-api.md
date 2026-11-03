# Attach Skia to a dasSDL3 window

The optional `require dasskia/skia_sdl3` module accepts real SDL_Window? and
SDL_GLContextState? from dasSDL3. Desktop and WASM use the same API and the same
[examples/sdl_interop.das](../examples/sdl_interop.das). No integer-pointer casts,
second SDL library, second daScript runtime or custom scene/event framework is used.

## Build the combined example host

Use the pinned dasSDL3 checkout from dependencies.json (a13e01f1, SDL 3.4.16 and
same daScript revision). This integration is OFF by default so the core binding
continues to build independently. It does not configure dasSDL3's top-level CMake
project or modify its source/generated snapshots.

```powershell
cmake -S . -B build/desktop -DDASSKIA_WITH_DASSDL3=ON "-DDASSKIA_DASSDL3_ROOT=$PWD/third_party/dasSDL3"
cmake --build build/desktop --target dasSkia_runner dasSkia_aot_runner dasSkia_interop_native --parallel 6
build/desktop/bin/dasSkia_runner.exe examples/sdl_interop.das
ctest --test-dir build/desktop --output-on-failure
```

In the existing Emscripten SDK/toolchain build, pass the same two options to
build/web, then build dasSkia_runner. The configured web page adds a dasSDL3 host
window link only when enabled. Browser tests add `--sdl-interop` to tools/test_web.py.
Native uses dasSDL3's saved clangbind snapshot; web uses its saved web module and
types. The latter is a smaller SDL profile; the example uses their common SDL API.
This does not claim every unrelated dasSDL3 API is available in web.

The combined target compiles these saved module sources against this build's
existing libDaScript and SDL3::SDL3 targets. A custom application host must link
core Skia plus the interop/native SDL module and register Module_dasSkia,
Module_dasSDL3 and Module_skiaSDL3. Map both dasskia and dassdl3 script roots.
Do not link a second independently built runtime/SDL or configure two top-level
projects together blindly. General SDK packaging/export is not provided by this integration.
Native strict AOT includes the imported sdl3_result script as well as the bridge.

## Host-owned SDL lifetime

```das
sdl_status(SDL_Init(SDL_INIT_VIDEO),"SDL_Init") |> skia_from_sdl() |> skia_try
configure_sdl_gl() |> skia_try  // before creating the host window/context
// Acquire/check window and context using dasSDL3, then:
let target : SkiaSDLTarget? = window |> with_sdl_target(context) |> skia_use
// This requires an outer skia_scope; target is borrowed inside its scope.
target |> with_sdl_frame() $(c : SkCanvas?) {
    c |> clear(0xff181c28u)
    return skia_ok()
} |> skia_try
sdl_status(SDL_GL_SwapWindow(window),"SDL_GL_SwapWindow") |> skia_from_sdl() |> skia_try
```

`configure_sdl_gl` explicitly sets the tested GL attributes: OpenGL 3.3 Core on
desktop, ES 3.0/WebGL 2 on web, RGBA8, double buffer, stencil 8. It does not create
resources or set swap interval. Existing compatible windows can attach without
calling it; it is only for setting attributes before host window creation.

`attach_sdl_window(window,context)` returns Result<SkiaSDLTarget?>. Window must have
SDL_WINDOW_OPENGL, initialized video and a live compatible context. Null handles,
non-GL windows or windows already using SDL_Renderer are rejected. SDL decides
whether the context can be made current on that window. Keep only one attached
Ganesh target per host context; duplicate wrappers are a caller lifetime contract,
not a native pointer registry.

The target owns only GrDirectContext and its wrapped SkSurface. It borrows both SDL
handles. `detach_sdl_window` destroys Skia GPU resources without destroying the SDL
window/context or decrementing SDL video lifetime. `with_sdl_target` scopes this
cleanup; body Err remains primary. Pointers lent by scopes must not escape.

Destroy/release any target-dependent GPU resources, detach, destroy GL context,
destroy SDL window, then quit SDL. Both handles must stay live through detach and
all operations use the SDL video/context thread. The adapter makes this context
current and leaves it current; it does not restore another previously selected pair.
An application may use its own dasSDL3 with_gl_current scope when appropriate.

## Frames, swap and events

`begin_sdl_frame` returns Result<SkCanvas?>. `end_sdl_frame` flushes/submits Skia GL
work and returns SkiaStatus. It **does not swap**. Prefer with_sdl_frame: it ends even
when its callback returns Err, keeps that body Err primary and reports an end error
only after a successful body. Nested begin, end without begin and pixel reads outside
an active frame return Err. There is no rollback of already issued GL commands or
panic/recover cleanup promise. A borrowed frame Canvas must not escape the frame.
Save/restore canvas state explicitly if your drawing changes matrices or clips.

The application exclusively polls/processes events, handles close requests, requests
SDL resize and calls SDL_GL_SwapWindow after a successful frame when desired. No event
queue is consumed by attachment or drawing. The existing convenience SkiaWindow
ownership/poll/present API remains separate and unchanged at script level.

The supported target is default framebuffer **0** with the tested RGBA8 configuration.
A bound nonzero FBO is rejected at begin. Arbitrary external FBOs, SDL_Renderer and
SDL_GPU swapchain interop are not supported by this GL attachment API. Begin resets
Ganesh's cached GL state to account for external GL between frames; the adapter does
not restore all GL state afterwards. Do not issue foreign GL calls or switch current
context/FBO inside a frame. Your other GL renderer must set its own state after end.

`sdl_frame_size` queries current drawable **pixels**, not logical SDL window units.
Begin recreates the wrapped surface when that pixel size changes; previous Canvas
aliases then expire. The host retains resizing policy. Zero/minimized drawable sizes
produce a begin Err; the host skips them with `prepare_sdl_frame` before begin. On web this
uses the SDL-owned canvas and WebGL context, not an OS window or CanvasKit.

`read_sdl_frame_pixel` copies a numeric unpremultiplied ARGB pixel during an active
frame and returns Result<uint>. It is synchronous readback intended for inspection,
not a frame presentation path. It does not swap. Out-of-bounds/readback errors propagate.
Use `prepare_sdl_frame` to skip minimized/zero-size/lost frames and lazily rebuild
Ganesh after WebGL restoration. `sdl_context_generation` identifies successful
rebuilds. SDL handles remain owned by the host. See [frame lifecycle](window-lifecycle.md).

`skia_from_sdl` explicitly converts standard Result<T,SdlError> to Result<T,SkiaError>,
preserving operation/message and transferring the value. SdlUnit and SkiaUnit remain
different value types; it is not an implicit success-unit conversion.

## Inventory

9 GL-window adapters (plus [6 raster-to-texture adapters](sdl-texture-api.md)),
**316 total with the 301 core adapters**:
Skia_ConfigureSDLGL, Skia_AttachSDLWindow, Skia_DetachSDLWindow, Skia_BeginSDLFrame,
Skia_EndSDLFrame, Skia_SDLFrameSize, Skia_ReadSDLFramePixel, Skia_PrepareSDLFrame,
Skia_SDLContextGeneration. Native module name is
skia_sdl3_native; script helper module is skia_sdl3, avoiding import name collision.
These are typed C++ adapters, not a stable C ABI. Core-only builds do not acquire a
dasSDL3 dependency.

## Example event loop and pacing

`examples/sdl_interop.das` requests VSync on its host-owned GL context and yields
for one millisecond per desktop frame, including when VSync is unavailable.
The browser uses requestAnimationFrame and does not call a blocking SDL_Delay.
The host handles Quit, Escape and WINDOW_CLOSE_REQUESTED for its own window;
a close event for another window does not stop it. app_quit releases Skia objects
before destroying the SDL context/window and quitting SDL.

Run `build/desktop/bin/dasSkia_runner.exe examples/sdl_interop.das` from the
project root. `examples` alone is a directory, not a runnable script.
The native `sdl_interop_events` CTest exercises the actual example callbacks,
injects each exit event and verifies SDL video shutdown. It does not establish
that every possible desktop/input/driver stall is fixed.
