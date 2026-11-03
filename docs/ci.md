# GitHub Actions CI

[The workflow](../.github/workflows/ci.yml) runs on push, pull request and manual
workflow_dispatch. It uses one Windows 2022 job for desktop and web: browser tests
compare native results and exchange SKP files with the native runner in the same
checkout. The workflow does not restore project build, dependency or AOT caches.

## What is checked

- Empty dependency/build directories at bootstrap; exact Git revisions and clean
  tracked sources for Skia, daScript, dasSDL3, SDL3 and the seven codec/text dependencies.
- Release desktop build of all targets, optional dasSDL3 adapters, generated native
  strict AOT and the full CTest suite (currently 79 tests).
- Actual software OpenGL rendering. A hash-checked Mesa llvmpipe DLL is deployed
  only beside the CI executables; gl_backend_native verifies the active renderer.
  A pinned standalone 7zr extracts the DLL without relying on runner tar codecs.
- Web interpreter and wasm32 strict AOT builds, using Emscripten 5.0.3 and the
  explicitly selected Node 22.3.0 AOT generator. Strict mode refuses interpreter
  fallback, missing entries and missing imported helpers.
- Chromium and Firefox: the full browser suite in interpreter and strict AOT
  profiles, plus context loss/restoration and SDL_Texture resize checks in each.
  Chromium requests SwiftShader; Firefox requests ANGLE/WARP. Renderer metadata
  records what the browser actually used. Tests run sequentially to bound memory.

[Tool versions, action commits and downloaded archive hashes](../ci/toolchains.json)
are pinned; [Python packages](../ci/requirements.txt) are pinned separately and
checked for consistency. actionlint checks the workflow syntax. Dependency pins
remain in dependencies.json and Skia DEPS.

An always-run artifact step retains logs, native JUnit XML, dependency audits,
renderer metadata, browser screenshots, GN arguments and CMake caches for 14 days.
Download `validation-<run id>-<attempt>` from the Actions run. Build executables and
Mesa binaries are not included. The workflow uses contents:read and does not keep
checkout credentials. After all checks pass on main, it uploads the strict AOT site and deploys it
to [GitHub Pages](https://spiiin.github.io/DasSkia/). Pull requests and other
branches do not deploy. Deployment verifies that build.json matches the checked
commit. Only the deploy job receives pages:write and id-token:write permissions.

## Run the same stages locally

Use a fresh checkout on Windows with Git, Visual Studio 2022 C++ tools and Python
3.12.4. Install Node 22.3.0 and select its executable before activating the SDK.
Run the desktop build in an x64 Visual Studio developer shell. From the source root:

```powershell
python -m pip install -r ci/requirements.txt
python -m playwright install chromium firefox
$env:DASSKIA_NODE = (Get-Command node).Source
python tools/ci.py lint
python tools/ci.py bootstrap
python tools/ci.py build-desktop
python tools/ci.py test-desktop
python tools/ci.py setup-emsdk
python tools/ci.py build-web
python tools/ci.py test-web
```

Stop after any failing command. Build stages default to six jobs. bootstrap
intentionally rejects an existing dependency/build tree. setup-emsdk installs its
own pinned SDK in build/emsdk; SDK activation stays inside child processes.
Browser checks use temporary localhost ports and stop their own servers on exit.
They do not use existing example servers.

## Results

Inspect the Actions run for the checked commit and download its validation
artifact for diagnostics. See [testing and support](../VALIDATION.md) for the
coverage matrix and platform limits.

Upstream tools: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[Mesa Windows builds](https://github.com/mmozeiko/build-mesa),
[actionlint](https://github.com/rhysd/actionlint),
[Emscripten SDK](https://github.com/emscripten-core/emsdk).
