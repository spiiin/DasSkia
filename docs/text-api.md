# Text and shaping

`require dasskia/skia_text` provides the same functions in native and WebAssembly.
Fonts are loaded from an explicit file; the web build preloads assets into its
virtual filesystem. Run native examples from the repository root or a build tree
containing the copied assets/ directory.

```das
options gen2
require dasskia/skia_text
require dasskia/skia_scope

def draw_label(c : SkCanvas?; paint : SkPaint?) : SkiaStatus {
    return skia_scope() {
        let font : SkFont? = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=32.0)) |> skia_use
        let text : SkiaText? = font |> with_shaped_text(
            "office • Привет • السلام عليكم",TextOptions(width=700.0,language="und")) |> skia_use
        c |> draw_text(text,float2(40.0,40.0),paint)
        return skia_ok()
    }
}
```

`examples/text.das` shapes once in app_init and draws the cached result each frame,
using the same script on desktop and web. It includes Latin ligatures, Cyrillic,
combining accents, Arabic and Hebrew, and releases the source font before rendering.

- `load_font(path,FontOptions)` returns Result<SkFont?>; destroy_font releases it.
- `shape_text(font,string,TextOptions)` returns Result<SkiaText?>; destroy_text releases it.
- `with_font_file` / `with_shaped_text` lend these resources in synchronous scopes.
- Text owns its blob and required typeface references; it can outlive the source
  font/string. Scope-borrowed text pointers themselves must not escape their scope.
- `TextOptions.width` controls wrapping; left_to_right sets the paragraph base
  direction. ICU still resolves mixed bidi runs. Text is left anchored; base RTL
  does not request right alignment. LF and CRLF split hard lines, including blank lines.
- language is a BCP-47-style tag (default und). ligatures and kerning control
  OpenType liga/clig and kern; required script shaping remains enabled.
- `draw_text(canvas,text,position,paint)` uses a top-left layout origin in canvas
  coordinates. The first baseline is positioned using font ascent.
- `text_metrics` reports maximum line advance, layout height, line/glyph counts and
  missing glyph count; these are layout metrics, not tight ink bounds.
- `font_metrics` reports ascent (normally negative), descent and leading.
- `text_glyph(text,index)` returns Result<TextGlyph> with copied glyph ID, position,
  bidi level and cluster. Clusters are byte offsets in the original UTF-8 string,
  including across hard lines; they are not character indices or caret positions.
- Empty text succeeds with zero lines/glyphs. Non-UTF-8 or embedded NUL input,
  nonpositive/nonfinite width, text over 1 MiB, and invalid font size return Err.
- Font size must be finite in (0,4096]. This simpler skia_text API has no automatic system-font fallback, style
  matching, rich-text layout, selection or hit testing. Rich layout and registered
  face matching are available separately through skia_paragraph. Unsupported
  characters use .notdef and increment missing_glyphs instead of silently loading
  a different font. A grapheme wider than the wrap width may overflow that width.

Both profiles use FreeType with grayscale AA, no hinting and linear/subpixel metrics.
The test compares glyph IDs, UTF-8 clusters, bidi levels and quantized positions
between the native and browser builds; GPU antialiasing pixels need not be identical.

Windows executables also need icudtl.dat next to the executable; CMake copies it
for each runner/tool. The web ICU data is linked into WASM (no extra data request).
Consumers embedding the static binding must link SkParagraph, SkShaper, SkUnicode ICU/core and
Skia, and deploy matching ICU data on Windows.
