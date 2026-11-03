# Text paints and OpenType features

`require dasskia/skia_paragraph` exposes the same SkParagraph text-style setters
on desktop and WASM. Paint construction/effects use the existing skia_boost,
skia_drawing and skia_effects modules. See [examples/text_style.das](../examples/text_style.das).

```das
let foreground : SkPaint? = with_paint(PaintOptions(color=0xffffffffu)) |> skia_use
let background : SkPaint? = with_paint(PaintOptions(color=0xff294e70u)) |> skia_use
var colors <- array(0xff39b5f0u,0xffffb55du)
let shader : SkShader? = linear_gradient(float2(0.0),float2(500.0,0.0),colors) |> with_shader() |> skia_use
foreground |> set_shader(shader)
style |> set_paragraph_foreground(foreground)
style |> set_paragraph_background(background)
style |> add_paragraph_font_feature("liga",1) |> skia_try
style |> add_paragraph_font_feature("kern",0) |> skia_try
// Create a builder with this style, or push it on an existing builder.
```

Use this inside skia_scope with the existing paragraph style/font collection.
The example runs unchanged using the native runner or the web Text paints and
features link. It shows gradient fill, background, outline text, and measured
advance with liga/kern enabled and disabled.

## Paint-backed styles

- `set_paragraph_foreground(style,paint)` calls native TextStyle.setForegroundPaint.
  SkPaint controls text rendering: solid/shader color, fill/stroke, blend mode and
  referenced paint effects follow Skia semantics. TextStyle.color remains stored;
  an explicit foreground takes precedence for glyph painting.
- `set_paragraph_background(style,paint)` uses native setBackgroundPaint. SkParagraph
  paints native background rectangles for the styled spans; this is not a CSS box,
  padding, rounded rectangle, clipping region or layout object. Paint effects/stroke
  follow the native background draw operation. It does not change text advance.
- Passing null, or omitting paint, clears the corresponding native flag.
  `style |> set_paragraph_foreground()` restores normal painting from the style's
  existing color. `style |> set_paragraph_background()` removes the background.
  Transparent foreground paint and cleared foreground are different states.
  Native clearing only changes the flag; stored paint resources can remain retained
  until that paint is replaced or the style is destroyed.
- Setters return void, matching Skia. They copy the SkPaint value and retain its
  ref-counted shader/filter/etc. They do not retain the caller's mutable paint pointer.
  Changing/destroying that paint afterwards does not change this style. Effects are
  shared immutable referenced resources, not deep copies of GPU/image storage;
  their existing context/lifetime restrictions still apply.
- Builder creation and push_paragraph_style copy the complete native TextStyle.
  Changing/clearing the source style later affects future uses, not existing builder
  blocks or built paragraphs. A paragraph can paint after original font/style/paint/
  shader handles have been destroyed. Borrowed scope pointers must not escape.
- Text geometry/selection bounds are layout metrics; stroke, blur and other effects
  may extend ink beyond them. There is no implicit clipping. Decoration color/settings
  remain native decoration properties; foreground paint does not replace every
  separate text-decoration setting. Shader coordinates follow SkCanvas/SkParagraph
  local drawing coordinates and the shader's existing local matrix.

## Font features

`add_paragraph_font_feature(style,tag,value=1)` returns SkiaStatus. It appends a native
TextStyle FontFeature. The tag must have exactly four printable ASCII bytes, is
case-sensitive and is copied into native SkString. Length-aware validation rejects
embedded NUL and invalid UTF-8/non-ASCII byte sequences. Value is a nonnegative int
(0..INT_MAX): typically 0 disables and 1 enables, but numbered alternates can take
other values if the font supports them. Up to 256 entries per style are accepted.
Invalid input/entry overflow returns Err without appending anything.

`reset_paragraph_font_features(style)` clears all explicit feature entries and
returns void. This restores the shaping engine/font defaults; it does not force
all features off. There is no per-tag erase operation in this API. Entries retain
native order, including duplicate tags. In the tested HarfBuzz profile a later
entry for the same tag/range overrides the earlier one; reset then add is often
clearer when constructing a new configuration.

Features apply to text ranges using that style in SkParagraph. They are not a global
font-manager switch. Native builder/style snapshot ownership applies to features
as well. Unsupported tags/values are passed to the shaping engine; accepting them
does not promise a glyph change or report font support. OpenType features and font
variation axes are different APIs; [variable-font arguments](typography-api.md) are available separately.

Both profiles use the pinned HarfBuzz/ICU/FreeType pipeline and explicit font files.
The test checks actual ffi ligature and AV kerning advances using bundled DejaVu Sans,
reset/unknown features, duplicate precedence and copied pushed-style features.
Native m138 adds liga=0 when positive letter spacing is enabled, after explicit
features. Therefore setting liga=1 does not override that native spacing policy.
Required shaping behavior for a script and engine defaults also remain native.

## Inventory and validation scope

Skia_SetParagraphForeground,
Skia_SetParagraphBackground, Skia_ParagraphAddFontFeature,
Skia_ParagraphResetFontFeatures. They have C++ linkage, not a stable C ABI.
The existing create_paragraph_style/with_paragraph_style API remains unchanged.

[Variation, decoration, shadow and baseline controls](typography-api.md) are available.
Caller-defined interactive editing policies remain outside the binding. No custom text renderer or JS
font-feature implementation is introduced.
