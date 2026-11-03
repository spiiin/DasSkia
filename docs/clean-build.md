# Build from fresh sources

Use a fresh checkout with no third_party/ or build/ directories.
Use installed Python 3, Git, CMake, Ninja, Visual Studio 2022 C++ tools, the pinned
Emscripten 5.0.3 SDK and the validated Node exception profile described in
[web-aot.md](web-aot.md). Python browser tests require Playwright and Pillow.

## Bootstrap

Clone the repository, then bootstrap its pinned dependencies:

```powershell
git clone https://github.com/spiiin/DasSkia.git
cd DasSkia
```

From the source root:

```powershell
python tools/bootstrap.py
```

For the complete optional dasSDL3 profile, fetch its exact revision separately:

```powershell
$lock = Get-Content dependencies.json -Raw | ConvertFrom-Json
$sdl = Join-Path (Get-Location) "third_party/dasSDL3"
git init $sdl
git -C $sdl fetch --depth 1 $lock.dasSDL3.url $lock.dasSDL3.revision
git -C $sdl checkout --detach FETCH_HEAD
```

This creates a fresh SDK checkout inside third_party; it does not use a sibling
working copy. Without interop, omit this checkout and the WITH_DASSDL3/ROOT flags
below. The web AOT inventory maps the SDK helper to /dassdl3/sdl3_result.das for
both internal and external SDK locations.

## Desktop

In an x64 Visual Studio developer shell, with Ninja on PATH:

```powershell
python tools/build_skia.py
cmake -S . -B build/desktop -G Ninja -DCMAKE_BUILD_TYPE=Release -DDASSKIA_AOT_TESTS=ON -DDASSKIA_WITH_DASSDL3=ON "-DDASSKIA_DASSDL3_ROOT=$sdl"
cmake --build build/desktop --parallel 6
ctest --test-dir build/desktop --output-on-failure
```

Build all targets before the full CTest run. Building only dasSkia_runner and
its AOT counterpart omits the native C++ pixel/lifecycle test executables. The AOT
generator and runner are built from these fresh dependencies; generated C++ from
another checkout is not copied into this build.

## Web

In the Emscripten environment, with Ninja and the validated Node on PATH:

```powershell
python tools/build_skia.py --web --emsdk $env:EMSDK
emcmake cmake -S . -B build/web -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS=-O1 -DDASSKIA_WEB_AOT=ON -DDASSKIA_WITH_DASSDL3=ON "-DDASSKIA_DASSDL3_ROOT=$sdl"
cmake --build build/web --target dasSkia_runner dasSkia_web_aot_runner --parallel 6
```

Set DASSKIA_NODE to an explicit validated node.exe if the SDK prepends a different
Node version to PATH. Node 22.3.0 was validated with --experimental-wasm-exnref.
If Ninja is not on PATH, explicitly pass CMAKE_MAKE_PROGRAM to configure. No original project cache,
library or generated AOT directory should appear in the fresh build rules.

Serve build/web/site for the interpreter and build/web/aot-site for strict AOT
on separate localhost ports. Against the strict site, run:

```powershell
python tools/test_web.py --url http://127.0.0.1:8112 --strict-aot --sdl-interop --native-runner build/desktop/bin/dasSkia_runner.exe
python tools/test_web.py --url http://127.0.0.1:8112 --strict-aot --sdl-interop --browser firefox --executable <firefox.exe> --native-runner build/desktop/bin/dasSkia_runner.exe
```

Also run the ordinary site without --strict-aot, and the focused
[test_web_lifecycle.py](../tools/test_web_lifecycle.py) and
[test_web_sdl_texture.py](../tools/test_web_sdl_texture.py) scripts on both profiles.
These checks verify execution/rendering and rejection of missing AOT; a successful
link alone is insufficient. See [testing and support](../VALIDATION.md) for coverage and platform limits.
Fresh builds do not imply byte-identical binaries across build paths.
