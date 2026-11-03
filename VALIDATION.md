# Testing and platform support

## Supported test profile

| Target | Build and execution |
| --- | --- |
| Windows x64 | Visual Studio 2022 / MSVC, Ninja, Release; interpreter and native strict AOT |
| WebAssembly | Emscripten 5.0.3, wasm32 SIMD, native Wasm exceptions, single thread; interpreter and wasm32 strict AOT |
| Browsers | Chromium and Firefox through Playwright, WebGL 2 |
| CI rendering | Mesa llvmpipe for native OpenGL, Chromium SwiftShader, Firefox ANGLE/WARP |

Exact dependency revisions are in [dependencies.json](dependencies.json); CI tools
and archive hashes are in [ci/toolchains.json](ci/toolchains.json).
[The workflow](.github/workflows/ci.yml) produces results for each checked commit.

The complete profile has been verified locally: **79 native tests**, full browser
suites in all four browser/execution combinations, and **12 focused browser checks**.
The full suite reports 43 PASS records per interpreter profile and 63 per strict
AOT profile, including three nested WASM-to-native interchange checks in each.
These are functional checks, not a performance or hardware acceleration benchmark.

## Coverage

- Raster bytes, alpha, clipping, layers, matrices, path geometry, image sampling
  and snapshot lifetime; errors and save-count restoration after a body error.
- PNG/JPEG/WebP file and byte roundtrips, independent codec fixtures and Pillow
  decoding, lossless alpha and tolerances for lossy output.
- Native OpenGL and browser WebGL rendering, inspected canvas pixels, resize,
  zero-size targets and frame lifecycle.
- Unicode shaping, bidi, ligatures, kerning, graphemes, UTF-8/UTF-16 conversion,
  rich paragraphs, selection geometry, placeholders, strut and typography.
  Shaping metadata is compared between native and web using the bundled fonts.
- Gradients, image shaders, SkSL uniforms/children, filter composition and retained
  resource lifetimes; SKP interchange between native and WebAssembly.
- Existing dasSDL3 OpenGL windows and raster-to-SDL_Texture upload, including
  ownership, padded row pitch, alpha conversion and transactional texture resize.
- Strict AOT entry points and app_quit, refusal of missing AOT entries and imported
  helpers, with interpreter fallback disabled.
- Repeated real WebGL loss/restoration, loss between frames, application listeners,
  resize and cleanup for both owned windows and existing dasSDL3 contexts.

## Run the checks

Follow [build instructions](docs/clean-build.md) for manual builds, or use the
[CI stages](docs/ci.md) for the full pinned software-rendering profile. Native
results are written as JUnit XML; browser logs, screenshots and renderer metadata
are included in the workflow's validation artifact. Local diagnostics live under
build/logs and build/browser-tests and are excluded from source control.

## Limits

- Linux, macOS, Safari/WebKit and mobile browsers have not been validated.
- Tests establish behavior for the pinned dependency/font/browser profiles;
  arbitrary fonts, scripts, Unicode locales and driver combinations are not
  guaranteed identical. Antialiasing and filter pixels can differ across backends.
- Fonts are loaded explicitly from files. There is no implicit OS font fallback.
  Caret and selection geometry do not implement an interactive editor or its
  visual bidi navigation policies.
- Full SVG documents, PDF, additional codecs, Graphite/WebGPU and SDL_GPU interop
  are outside the current API. SKP is versioned by Skia, not a stable interchange
  format across arbitrary Skia versions.
- Applications recreate their own GPU resources after context restoration.
  In-flight frame failures and native driver resets remain application concerns.
- Raw pointer lifetimes remain caller contracts; scope helpers do not provide a
  static borrow checker or recover cleanup from arbitrary script panic.
- Strict AOT still loads script sources and verifies semantic hashes. It is not a
  source-free deployment format. Only scripts and imported helpers included in the
  AOT inventory can execute in strict mode.
