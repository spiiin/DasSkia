# Placeholders and strut

`require dasskia/skia_paragraph` provides native SkParagraph placeholders and
StrutStyle on desktop and WASM. See [examples/inline_layout.das](../examples/inline_layout.das).

## Inline objects

```das
builder |> add_paragraph_text("Before ") |> skia_try
let marker=builder |> add_paragraph_placeholder(ParagraphPlaceholderOptions(
    size=float2(48.0,36.0),baseline_offset=30.0)) |> skia_try
builder |> add_paragraph_text(" after") |> skia_try
let paragraph : SkiaParagraph? = build_paragraph(builder) |> with_paragraph() |> skia_use
paragraph |> layout_paragraph(500.0) |> skia_try
var boxes <- paragraph |> paragraph_placeholder_rects() |> skia_try
for (box in boxes) {
    let r=box.rect
    canvas |> draw_rect(float4(r.x+origin.x,r.y+origin.y,r.z,r.w),object_paint)
}
canvas |> draw_paragraph(paragraph,origin)
```

`add_paragraph_placeholder` returns Result<ParagraphTextRange> identifying the
inserted marker in both encodings. SkParagraph inserts U+FFFC: **3 UTF-8 bytes,
1 UTF-16 unit**. The adapter mirrors that insertion in all existing conversion,
grapheme, selection and hit-test indices. Offsets after a placeholder include it.
A literal U+FFFC supplied through add_paragraph_text is ordinary text, not an inline
object. No image, resource pointer or drawing callback is attached to placeholders.

ParagraphPlaceholderOptions has size (default 24x24), alignment, baseline and
baseline_offset. Width/height must be finite and nonnegative; offset must be finite
and may be negative or outside the rectangle. Baseline alignment is the default;
its offset is the distance from rectangle top to its baseline. Setting offset to
height places its bottom on the surrounding baseline. AboveBaseline, BelowBaseline,
Top, Bottom and Middle are native PlaceholderAlignment modes. Text baseline is
Alphabetic or Ideographic. Native baseline choice applies to baseline-related modes;
Top/Bottom/Middle follow native line placement.

Placeholder insertion respects the existing consumed-builder/style-stack rules and
1 MiB UTF-8 limit (including the three inserted bytes). Invalid dimensions/enums or
a full builder return Err before changing builder state. A successful insertion does
not change the active pushed text style. A zero-size placeholder still adds a marker.

`paragraph_placeholder_rects` returns Result<array<ParagraphTextBox>> after layout:
paragraph-local XYWH and native direction, copied into language-owned values. It
uses native getRectsForPlaceholders and preserves its ordering/visibility behavior.
This is not a guaranteed one-rectangle-per-insertion ID mapping: hidden/zero-size
objects may be omitted. The pinned implementation keeps placeholder source order
through bidi reordering. The example has three visible, positive-size placeholders.
Use the returned marker ranges with paragraph_rects_utf16/utf8 when querying a
particular source range; those queries retain their native grapheme semantics.

The returned array survives relayout or paragraph destruction. Query again after
reflow to obtain new geometry. No clipping of caller-drawn content is imposed. Skia
reserves object space and paints surrounding text; the application draws icons,
images or controls at the returned bounds. Hidden ellipsized objects have no visible
box; layout indices still refer to the original text including their markers.

## Strut

```das
let strut : SkiaParagraphStrut? = strut_font_style |> with_paragraph_strut(
    ParagraphStrutOptions(height=1.5,height_override=true,force_height=true)) |> skia_use
let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body_style,strut,
    ParagraphOptions()) |> skia_use
```

`create_paragraph_strut(font_style,ParagraphStrutOptions())` returns an opaque owned
native StrutStyle. Its family list, SkFontStyle and font size are copied from the
provided paragraph text style. Color, decorations, text spacing and TextStyle.height
are irrelevant to this font configuration. Font files must be registered in the
FontCollection used by the builder; no OS fallback manager is installed.

ParagraphStrutOptions exposes native controls:

| Field | Default | Meaning |
| --- | --- | --- |
| enabled | true | Enable strut when explicitly supplied to a builder |
| height | 1 | Positive finite font-size multiplier, used with height_override |
| leading | -1 | Finite font-size-relative leading; negative means no added leading in m138 |
| force_height | false | Force strut metrics even when text ink needs more space |
| height_override | false | Use height multiplier rather than native font metrics |
| half_leading | false | With height_override, split extra height equally above/below rather than scale ascent/descent |

Strut supplies a minimum line metric by default. Larger text or inline objects can
increase a line. Force height can produce overlap or ink outside those metrics;
it does not scale fonts, shrink objects or clip drawing. Strut does not promise a
visual bounding box for every font/glyph. In the example, a 32 px font with height=1.5,
height_override=true and force_height=true supplies a 48 px line grid.

The overloads create_paragraph_builder(fonts,style,strut,settings) and
with_paragraph_builder(fonts,style,strut,settings,block) copy the strut into native
ParagraphStyle. Null strut keeps default behavior. The original overload without a
strut remains supported, as does its raw Skia_NewParagraphBuilder signature.

Destroy a strut with destroy_paragraph_strut or use with_paragraph_strut. The text
style may be destroyed after strut creation; the strut may be destroyed after builder
creation. A built paragraph owns the copied settings and its font collection. Scoped
borrowed pointers cannot escape. Standard Result/defer helpers preserve body errors.
RectHeightStyle.Strut can be selected through ParagraphRectOptions to query native
strut-based selection rectangles.

## Native inventory

Skia_NewParagraphStrut, Skia_DeleteParagraphStrut,
Skia_NewParagraphBuilderWithStrut, Skia_ParagraphAddPlaceholder,
Skia_ParagraphPlaceholderRects. Raw rectangle snapshots use the existing explicit
DeleteParagraphRects lifetime. These have C++ linkage, not a stable C ABI.

[Text paints and font features](text-style-api.md) are available.
[Font variations, decoration, shadow and baseline controls](typography-api.md) are available.
Interactive editing remains caller policy.
