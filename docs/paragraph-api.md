# SkParagraph

`require dasskia/skia_paragraph` adds rich text layout on CPU raster surfaces,
recording canvases and SDL Ganesh GL / WebGL 2 canvases. Desktop and WASM share
SkParagraph, FreeType, HarfBuzz, ICU and explicit font files. No CanvasKit or JS
text API is involved.

## Create and draw

```das
options gen2
require dasskia/skia_paragraph
require dasskia/skia_scope

def paragraph_example(c : SkCanvas?) : SkiaStatus {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let body : SkiaParagraphTextStyle? = with_paragraph_style(families,
            ParagraphTextOptions(size=24.0,color=0xffeeeeeeu)) |> skia_use
        let accent : SkiaParagraphTextStyle? = with_paragraph_style(families,
            ParagraphTextOptions(size=32.0,color=0xffffb55du,decorations=PARAGRAPH_UNDERLINE)) |> skia_use
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body,
            ParagraphOptions(max_lines=3,ellipsis="…")) |> skia_use
        builder |> push_paragraph_style(accent) |> skia_try
        builder |> add_paragraph_text("Hello! ") |> skia_try
        builder |> pop_paragraph_style() |> skia_try
        builder |> add_paragraph_text("Привет • العربية • שלום") |> skia_try
        let paragraph : SkiaParagraph? = build_paragraph(builder) |> with_paragraph() |> skia_use
        paragraph |> layout_paragraph(500.0) |> skia_try
        c |> draw_paragraph(paragraph,float2(20.0,20.0))
        return skia_ok()
    }
}
```

Run `examples/paragraph.das` using either runner; the web page has a Rich paragraphs
link. It shows multiple styles, decorated text, bidi, explicit RTL and ellipsis.

## Fonts and styles

- `create_paragraph_fonts` / `destroy_paragraph_fonts` manage a native FontCollection
  and its TypefaceFontProvider. `add_paragraph_font(fonts,path,family)` loads through
  FreeType and registers an explicit family alias. Register all faces before making
  any builder: the collection is then sealed. Each alias may contain multiple faces;
  native SkFontStyle matching chooses among registered weight/width/slant variants.
- Font-family arrays are ordered: SkParagraph tries registered families for unresolved
  spans. Automatic per-codepoint system fallback is disabled. Native default-family
  matching may select another registered face when none of the requested families
  match; no OS font manager is installed. Bundle every required font file in web assets.
- `create_paragraph_style(families,ParagraphTextOptions)` copies family names and locale.
  Options specify size, ARGB color, weight 1..1000, font_width 1..9, italic, letter/word
  spacing, height multiplier and decoration bits (underline=1, overline=2, line-through=4).
  Weight/slant request native face matching; they do not guarantee synthetic bold/italic
  when only one regular face is registered. Positive height overrides font line height;
  zero uses native metrics. Font size is finite in (0,4096]. Spacing must be finite.
- Builder creation and push copy native styles. A pushed style fully replaces the
  current style until pop; it is not a partial CSS-style override. Pops must balance.
- ParagraphOptions has Left/Right/Center/Justify/Start/End alignment, LTR/RTL base
  direction, max_lines (0 means unlimited) and UTF-8 ellipsis. Ellipsis is not a clip.
  Paragraph hinting and the legacy rounding hack are disabled in both profiles.

## Ownership and state

All four opaque adapters are deleted with their matching `destroy_paragraph_*`
(or `destroy_paragraph`) helper. Synchronous `with_*` helpers enter cleanup only
once acquisition succeeds and preserve a body Err. Pointers lent by blocks cannot
escape. A newly built, separately owned paragraph can be returned from a builder
block; its font collection, text and styles outlive the builder/style/font handles.

A builder is consumed once by successful `build_paragraph`. Failed validation does
not consume it. Add/push/pop/build afterwards return Err. Up to 256 nested styles
and 1 MiB total valid UTF-8 text without embedded NUL are accepted. Ellipsis is at
most 4096 UTF-8 bytes. These limits are adapters' validation limits, not Skia ABI.

Call `layout_paragraph` with a finite positive width before paint or metrics. Repeat
layout on the same object to reflow at a new width. `draw_paragraph` returns void,
matching Skia's paint, and takes the paragraph top-left position. Painting does not
clip overflowing glyphs. Drawing before layout violates its precondition.

## Metrics

`paragraph_metrics` returns Result<ParagraphMetrics>: layout width/height, intrinsic
widths, alphabetic/ideographic baselines, longest line, number of returned line-metric
records, unresolved glyph count, exceeded_max_lines. Missing glyphs are reported,
not treated as a layout failure. `unresolved_glyphs=-1` preserves Skia's unshaped
state; in this pinned version a laid-out empty paragraph has positive font height,
zero line records and unresolved=-1. This differs from the simpler skia_text empty
text contract.

`paragraph_line_metrics(paragraph,index)` returns copied ascent/descent (positive),
height, width, left, baseline and hard_break for a zero-based line. Heights and
baselines follow native SkParagraph metrics; they are not tight glyph ink bounds.
Queries before layout or outside line records return Err. Relayout replaces metrics.
Text indices, hit testing, ICU word boundaries, copied range boxes and explicit
UTF-8/UTF-16 mapping are available in [the selection API](selection-api.md).
[Placeholders and strut](inline-layout-api.md) and [text paints/font features](text-style-api.md)
are also available, along with [font variations and typography controls](typography-api.md).

## Core paragraph adapters

ParagraphError, NewParagraphFonts, DeleteParagraphFonts, ParagraphAddFont,
NewParagraphTextStyle, DeleteParagraphTextStyle, ParagraphStyleFamilies,
NewParagraphBuilder, DeleteParagraphBuilder, ParagraphPushStyle, ParagraphPopStyle,
ParagraphAddText, BuildParagraph, DeleteParagraph, LayoutParagraph,
ParagraphMetrics, ParagraphLineMetrics, DrawParagraph (all prefixed `Skia_`).

These are C++ adapters, not a stable C ABI. SkParagraph is linked before SkShaper,
SkUnicode ICU/core and Skia. Public complex native text styles remain opaque heap
objects; script option/metric structs contain language-owned values.
