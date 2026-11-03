# Recorded pictures

SkPictureRecorder and SkPicture record and replay drawing commands. The same
C++ implementation and script API run on desktop and WebAssembly.

## Recording and lifetime

`record_picture(PictureOptions(bounds=XYWH,bbh=false),callback)` creates a recorder,
passes its borrowed recording Canvas to a callback returning SkiaStatus, then
finishes to Result<SkPicture?,SkiaError> on Ok. Body Err is returned unchanged and
the active recorder is deleted without publishing a partial result. Invalid
bounds skip the body. Cleanup uses the existing defer contract, not a panic bridge.

For explicit control, use `with_picture_recorder`, `begin_recording`,
`recording_canvas` and `finish_recording`. Bounds must have finite coordinates,
nonnegative width/height and finite right/bottom edges. Double begin returns Err
and preserves the active recording. Finish while inactive returns Err. The
finish overload with cull XYWH checks it first; invalid cull leaves recording
active. A recorder can be reused after a successful finish.

The recording Canvas is owned by the recorder and must never be deleted. It
becomes invalid at finish or recorder destruction, even when a later begin
happens to reuse the same address. `recording_canvas` returns null while inactive.
Record callbacks must not retain their Canvas. Finish balances unmatched saves.

The resulting SkPicture is immutable and owns the native resources needed for
replay: recorded Paint/path values, image/typeface/text-blob references and nested
pictures. Input resources can leave their scopes before replay. With manual
ownership, use Skia_PictureUnref and Skia_DeletePictureRecorder. `with_picture`
consumes a successful Result, lends the picture synchronously, then unrefs once
including on body Err. Factory Err skips its body. Result itself is not RAII.

## Bounds, drawing and statistics

Cull bounds are a culling hint, not a clip. Drawing outside them is undefined in
Skia and may be discarded. Use clip_rect explicitly when clipping is required.
`bbh=true` enables an R-tree; native finish can tighten final cull bounds to its
estimated recorded content. An empty recording successfully produces an empty
picture, whose final cull may be empty regardless of the initial bounds.

`draw_picture(canvas,picture,transform=matrix(),paint=null)` preserves destination
matrix/clip/save state. An optional Paint applies alpha, color/image filters and
blend mode to a **group layer** containing the picture. This differs from applying
alpha separately to each draw. Transform composes with the destination matrix.

`playback_picture(picture,canvas)` directly replays individual recorded commands.
When the destination is another recorder, draw_picture can retain a nested
picture, while playback_picture expands the commands into that recorder. Skia
can optimize small pictures/commands in either case; no exact op-count is promised.

`picture_stats(picture,nested=false)` returns cull XYWH, nonzero process-local id,
approximate operation count and approximate byte use (uint64). Id is not a
persistent key and is not preserved by deserialization. Memory estimates exclude
some referenced resources and vary by architecture. A picture is a command list,
not a guarantee of a cached raster image or a performance improvement.

## Serialization

- `serialize_picture(picture)` returns Result<array<uint8>,SkiaError>. Bytes are
  copied into an owned script array; no native pointer escapes. The raw adapter
  resizes its output array on success, rejecting sizes above uint32 capacity.
- `picture_from_bytes(bytes)` copies input before decoding. The array can then
  be mutated or released while decoded pictures/images remain alive.
- `save_picture(picture,path)` returns SkiaStatus; `load_picture(path)` returns a
  picture Result. Desktop paths use the host filesystem, web paths use the
  Emscripten virtual filesystem. This does not initiate a browser upload/download.

SKP is Skia's versioned binary picture format, not SVG, PDF, a stable interchange
ABI, or a forward-compatible application document format. Interchange is tested
for this project's pinned native/WASM profiles; other Skia revisions or codec/font
configurations are outside that guarantee. Decode reports native format acceptance,
not that every arbitrary externally supplied font/effect is supported.

The adapter explicitly serializes source images: existing encoded image data is
reused, otherwise CPU images are PNG-encoded. Encoding failure returns Err rather
than silently publishing a missing image. Unencoded texture-backed images need
a GPU context for readback; this serializer does not take one. No GPU readback
is silently requested. Native typeface serialization embeds font data; the pinned
FreeType decoder is enabled on both targets. Full embedded fonts can make small
pictures large; font subsetting is not implemented. Shaped glyph
positions are recorded for drawing; original text layout/editing metadata is not
an independent SkiaText object after loading a picture.

File writes can leave a partial file after an I/O failure, following Skia's stream
behavior. As elsewhere, fatal allocation behavior follows native Skia; there is
no recoverable out-of-memory promise.

## Picture shaders

`picture_shader(picture,PictureShaderOptions())` returns a Shader Result, usable
with the existing with_shader/set_shader API. Defaults are Repeat in X/Y, Linear
filtering, identity local matrix and the picture cull rect as tile bounds.
`custom_tile=true` selects tile XYWH in picture coordinates; the matrix maps
shader coordinates into local canvas coordinates. Tile bounds must be finite and
nonnegative. Empty tiles and singular matrices follow Skia's shader behavior.
The shader retains the picture, and Paint retains the shader, so both source
scopes can finish before drawing. The tile's matrix does not alter the recorded
picture; filtering can differ between CPU and GPU rasterization.

## Native inventory

| Family | Count | Adapters (Skia_ prefix omitted) |
| --- | ---: | --- |
| Recorder | 6 | NewPictureRecorder, DeletePictureRecorder, BeginPictureRecording, PictureRecordingCanvas, FinishPicture, FinishPictureWithCull |
| Picture | 5 | PictureUnref, PictureCull, PictureID, PictureOpCount, PictureBytes |
| Replay | 2 | DrawPicture, PlaybackPicture |
| Serialization | 4 | SerializePicture, DeserializePicture, SavePicture, LoadPicture |
| Shader | 1 | PictureShader |
