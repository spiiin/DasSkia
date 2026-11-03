# Strict Web AOT

Desktop and web use the same daScript API and scripts, including optional dasSDL3
window integration. Strict web AOT compiles the listed scripts to C++, then links
that code into a separate WebAssembly runner. The runner still loads the script
sources and checks semantic hashes at startup. Missing AOT is an error; it does
not fall back to interpretation. This is not a source-free deployment profile.

## Build

Use the pinned Emscripten 5.0.3 environment and the existing web Skia build.
The validated generator host is Node.js 22.3.0 with
`--experimental-wasm-exnref`, required for this SDK's native Wasm exception ABI.
Node must be on PATH, or set `DASSKIA_NODE` to its executable. Override
`DASSKIA_NODE_FLAGS` only when validating a different Node/exception profile.

```powershell
emcmake cmake -S . -B build/web -DDASSKIA_WEB_AOT=ON
cmake --build build/web --target dasSkia_web_aot_runner --parallel 6
python -m http.server 8080 --bind 127.0.0.1 --directory build/web/aot-site
```

For existing dasSDL3 windows, also configure both builds with
`-DDASSKIA_WITH_DASSDL3=ON "-DDASSKIA_DASSDL3_ROOT=$PWD/third_party/dasSDL3"`.
Open `http://localhost:8080/?script=/examples/sdl_interop.das` or select another
example. Keep the generated JS, WASM and data files together.

To run a desktop example from the project root:

```powershell
build/desktop/bin/dasSkia_runner.exe examples/typography.das
build/desktop/bin/dasSkia_aot_runner.exe examples/typography.das
```

The ordinary `dasSkia_runner` target and `build/web/site` remain available.
`DASSKIA_WEB_AOT` defaults to OFF.

## Generation and inventory

`dasSkia_web_aot_generator` is itself wasm32, executed under Node. It uses the
same libraries, compiler layout and virtual input paths as the browser runner:
`/dasskia`, `/examples`, `/tests`, `/assets`, `/daslib` and optional `/dassdl3`.
Only `/aot-output` is mounted to the host output directory using NODEFS.
Do not reuse generated desktop C++: pointer sizes, layouts and semantic hashes
can differ. Generated web C++ lives in `build/web/aot-web`; the generator lives
in `build/web/aot-tools`.

`cmake/ScriptInventory.cmake` lists scripts and imported helper modules for both
native and web AOT. Add new runnable scripts and dependencies there before using
them with the strict runner. The optional SDK's `sdl3_result.das` is included.
Script/data changes trigger regeneration or repackaging through CMake dependencies.

## Verify

Install Playwright, Pillow and the selected browser, then run against the strict
site, keeping the local server running:

```powershell
python tools/test_web.py --url http://127.0.0.1:8080 --strict-aot --sdl-interop --native-runner build/desktop/bin/dasSkia_runner.exe
python tools/test_web.py --url http://127.0.0.1:8080 --strict-aot --sdl-interop --browser firefox --executable <firefox.exe> --native-runner build/desktop/bin/dasSkia_runner.exe
```

Omit `--sdl-interop` when that module is disabled. Positive checks require
`STRICT_AOT=1; fallback disabled` and AOT entry markers, compare text signatures
with native, inspect canvas pixels and test SKP interchange. Sixteen lifecycle
examples (with interop enabled) also run three frames with `&smoke=1` and check
`app_quit` AOT before cleanup. Normal interactive pages keep running.

Two negative fixtures verify refusal to execute missing AOT: `aot_missing.das`
has no linked entry; `aot_import_missing.das` has a linked entry but its imported
`aot_unlinked.das` helper deliberately has no linked artifact. The helper has an
observable side effect so optimization cannot replace the test call with a
constant. Neither fallback execution marker may run. These fixtures are not
application examples; the latter entry is added only by `WebAOT.cmake`.

Browser screenshots, interchange fixtures and negative diagnostics are saved in
`build/browser-tests` with `chromium-aot` / `firefox-aot` prefixes. See
[VALIDATION.md](../VALIDATION.md) for measured results and platform limits.
