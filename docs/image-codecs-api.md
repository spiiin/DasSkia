# PNG, JPEG and WebP: shared native/web API

`require dasskia/skia_codecs` adds image encoding and owned image-loading helpers.
Existing `with_image_file(path)` and raw Skia_LoadImage also decode JPEG/WebP when
built with the supplied profile. Format recognition uses encoded contents, not
the filename suffix. There is no CanvasKit or separate JS image decoder.

## File and byte operations

| Operation | Result |
| --- | --- |
| load_image(path) | Result<SkImage?>, owned image |
| with_image_file(path, block) | Existing synchronous image scope |
| image_from_bytes(bytes) | Result<SkImage?>, copies encoded bytes |
| with_image_bytes(bytes, block) | Synchronous scope; unrefs image after block |
| save_jpeg(surface, path, JpegOptions()) | SkiaStatus |
| save_webp(surface, path, WebpOptions()) | SkiaStatus |
| save_png(surface, path) | Existing SkiaStatus operation |
| encode_jpeg(surface, JpegOptions()) | Result<array<uint8>> |
| encode_webp(surface, WebpOptions()) | Result<array<uint8>> |
| encode_png(surface) | Result<array<uint8>> |

All encode/save functions accept CPU raster surfaces. They do not implicitly read
GPU surfaces back. Returned byte arrays own copied data. image_from_bytes also
copies its input into retained SkData; the original array may be changed or freed
before lazy decoding. Owned SkImage pointers use Skia_ImageUnref; scope pointers
must not escape their block. Scope cleanup preserves primary body errors.

Image loading keeps Skia's deferred decoding model. Recognizing a header does not
prove every pixel of a truncated/corrupt file can decode. Actual decoding can
happen when drawing or reading pixels; this API does not add a complete eager-file
validation promise. Empty/unrecognized encoded headers return Err.

```das
require dasskia/skia_codecs
require dasskia/skia_scope

return skia_scope() {
    let surface : SkSurface? = with_raster_surface(
        RasterSurfaceOptions(size=int2(640,480))) |> skia_use
    canvas(surface) |> clear(0xff39b5f0u)
    surface |> save_jpeg("output.jpg", JpegOptions(quality=90,
        downsample=SkiaJpegDownsample.YUV444)) |> skia_try
    var bytes <- surface |> encode_webp(WebpOptions(quality=75.0,
        compression=SkiaWebpCompression.Lossless)) |> skia_try
    let image : SkImage? = with_image_bytes(bytes) |> skia_use
    // image can be drawn using the existing image APIs.
    return skia_ok()
}
```

## Encoder options

JpegOptions mirrors the native defaults:

- quality: int, default 100, range 0..100.
- downsample: SkiaJpegDownsample.YUV420 (default), YUV422 or YUV444.
- alpha: SkiaJpegAlpha.Ignore (default) or BlendOnBlack.

JPEG is opaque. Alpha handling follows SkJpegEncoder's native pixel semantics,
including premultiplied input; Ignore does not add a custom unpremultiply/matte
operation. BlendOnBlack is explicit for a black background. For a different matte,
first composite into an opaque raster surface of that color, then encode.
Lossy RGB comparisons require a tolerance; quality is not a target byte size.

WebpOptions mirrors native defaults:

- compression: SkiaWebpCompression.Lossy (default) or Lossless.
- quality: finite float in 0..100, default 100.

With Lossy, quality controls visual quality. With Lossless, it controls compression
effort: higher effort may take longer and produce smaller files, while decoded
pixels remain lossless relative to encoder input. Both modes support alpha.
Premultiplied raster conversion can round channel values; hidden RGB at zero alpha
is not a preservation contract. Still-image encoding is exposed, not animated
WebP frame/timing controls, metadata editing or arbitrary ICC overrides.

Invalid options are rejected without opening an output file or changing a byte
output array. File encode happens before opening the output stream; write errors
are reported, but saving is not an atomic filesystem replacement/fsync guarantee.
Allocation and fatal OOM follow the existing Skia/host contract.

## Build and dependencies

The build script enables JPEG and WebP decode/encode and disables system versions
for both profiles. libjpeg-turbo e14cbfaa and libwebp 845d5476 come from the pinned
Skia m138 DEPS. Exact URLs/revisions are also in dependencies.json. Source files
in dependencies were not patched. Notices are in licenses/libjpeg-turbo and
licenses/libwebp and summarized in THIRD_PARTY_NOTICES.md.

For an existing checkout:

```powershell
python tools/bootstrap_skia_deps.py --only libjpeg-turbo libwebp
python tools/build_skia.py
python tools/build_skia.py --web --emsdk $env:EMSDK
```

Normal `tools/bootstrap.py` fetches these dependencies too. Rebuild the native and
web binding targets after rebuilding their Skia libraries. For strict wasm32 AOT,
follow [web-aot.md](web-aot.md); native64 generated C++ is not reused. The helper,
pixel test and example are in the shared AOT inventory.

Web file paths refer to the Emscripten virtual filesystem. Saving there does not
by itself download a file to the user's disk. Byte-array operations let the host
supply/upload/download encoded data through its existing application integration.
The same daScript API is used on native; filesystem ownership remains with the host.

## Example and validation

[examples/codecs.das](../examples/codecs.das) displays original PNG, two JPEG
qualities/downsampling modes, lossy/lossless WebP and an independently encoded
alpha fixture over a checkerboard. It encodes once during initialization, logs
actual encoded sizes and writes codec-example.jpg / codec-example.webp. It does
not assume WebP is always smaller than PNG or JPEG.

```powershell
build/desktop/bin/dasSkia_runner.exe examples/codecs.das
build/desktop/bin/dasSkia_aot_runner.exe examples/codecs.das
ctest --test-dir build/desktop -R codecs --output-on-failure
```

Open `?script=/examples/codecs.das` on the ordinary or strict web site. The browser
suite includes real canvas pixels, JPEG/WebP file+byte roundtrips, exact lossless
and alpha checks, lossy tolerances, output errors and copied-byte ownership.
Pillow independently decodes browser-produced JPEG and both WebP modes, including
alpha. Independent procedural input fixtures and their generator versions/hashes
live under assets/images; tests also validate filename-independent detection.
These cover the tested RGB JPEG and RGB/RGBA still WebP cases, not every possible
metadata/animation/color-management configuration.

7 new native adapters: Skia_SaveJpeg, Skia_SaveWebp, Skia_EncodeJpeg,
Skia_EncodeWebp, Skia_EncodePng, Skia_ImageFromBytes and Skia_CodecError.
Core **301**, optional SDL interop **15**, total **316**. Raw adapters use C++
linkage and retain existing ownership rules. See [VALIDATION.md](../VALIDATION.md)
for actual results and build profiles.
