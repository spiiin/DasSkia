# Font variations, TTC and typography controls

`require dasskia/skia_paragraph` exposes this API identically on native and WASM.
See [examples/typography.das](../examples/typography.das). The example uses checked-in,
hash-verified font fixtures with accompanying licenses; no OS font lookup or JS
font-loading API is required.

## Variation coordinates and metadata

```das
var axes <- array(FontVariation(tag="wght",value=2.0))
style |> set_paragraph_font_arguments(axes) |> skia_try
// Build/push style now. Later mutations of axes/style do not affect that snapshot.
style |> clear_paragraph_font_arguments()
```

Coordinates are copied into native TextStyle FontArguments, including when the
input array goes out of scope. Tags must be four printable ASCII bytes; values must
be finite. At most 64 unique axes are accepted. Duplicate axes, invalid tags, NaN/
infinity and negative collection index return Err before replacing existing arguments.
Empty coordinates still set a native FontArguments value; clear removes the optional
arguments entirely. Unknown axes and out-of-range coordinates follow native Skia/
FreeType behavior (ignored or clamped by the font/backend); setters do not validate
against a particular family or promise a visible change. Font-manager resolution
can choose different registered families, so inspect the intended font when needed.

`font_variation_axes(font : SkFont?)` returns Result<array<FontVariationAxis>> from
an existing file-loaded font. Each axis has tag, minimum, normal, maximum and hidden.
Static fonts return an empty array. Query errors return Err; enumeration is capped
at 1024 axes. The existing skia_text with_font_file helper can load the same variable
font for inspection; it loads face 0. Returned metadata are copied language values.

The fixture Distortable.ttf is an unmodified Skia OFL test font with only a/b/c and
wght in **0.5..2.0**, default 1.0. Its advance remains fixed while contours vary;
tests compare actual raster outlines. Arbitrary axis tags, including wdth/opsz, are
supported by the adapter but only affect fonts that contain those axes. This fixture
does not claim coverage for every variable-font technology or axis.

## TTC face selection

`add_paragraph_font(fonts,path,family,face_index)` loads the requested face through
the same FreeType manager before registering its alias. Nonnegative index required;
a missing/unsupported face returns Err. Register before the collection is sealed.
The existing three-argument call still loads face 0.

The optional face_index argument of set_paragraph_font_arguments is copied to native
SkFontArguments.collectionIndex. **In pinned m138 FreeType makeClone keeps the already
loaded TTC face**, so changing this field is not a face-switching mechanism. Select
the face at registration and use its alias; variations clone that selected face.
No fake promise of switching a collection face through a style argument is made.

ExampleCollection.ttc contains Distortable (face 0) and DejaVu Sans (face 1), generated
with fontTools and original glyph/axis/name data. It is a test fixture, not a new font
family. See assets/fonts/TEXT-ASSETS.md, both licenses and dependencies.json for its
provenance/hashes. Normal build/bootstrap only verifies these checked-in files;
fontTools is not a runtime or standard-build requirement.

## Decorations

`set_paragraph_decoration(style,ParagraphDecorationOptions(...))` returns SkiaStatus.
Options: bits (underline=1, overline=2, line-through=4; default 0 clears), ARGB color,
SkiaTextDecorationStyle Solid/Double/Dotted/Dashed/Wavy, mode Gaps/Through and finite
nonnegative thickness multiplier (default 1). These map to native TextStyle methods.
Thickness is a multiplier of native decoration thickness, not a pixel stroke width.
Gaps/Through follow native glyph-intersection behavior. In pinned m138, Gaps
can omit an underline when its intercept calculation finds no glyph intersections;
the example uses Through so all five styles are visible. The binding does not patch
this upstream behavior. Foreground paint remains
independent of decoration color. Existing ParagraphTextOptions.decorations remain
supported; this setter adds the remaining native properties.

## Text shadows

`add_paragraph_shadow(style,ParagraphShadowOptions(...))` appends a copied native
TextShadow: ARGB color, float2 offset and blur_sigma (standard deviation, not CSS
blur radius). Offset must be finite and sigma finite/nonnegative; at most 256 shadows.
Invalid input leaves the style unchanged. Multiple shadows retain native order and
painting behavior; ink may extend beyond layout/selection bounds. There is no implicit
clip. `reset_paragraph_shadows(style)` clears explicit shadows and returns void.

## Baseline shift and text height

`set_paragraph_baseline_shift(style,float)` validates a finite value, then sets the
native TextStyle shift. In the tested profile negative raises and positive lowers
that run relative to adjacent normal text. It does not automatically reduce font
size or select OpenType superscript/subscript glyphs; the example combines a smaller
style with explicit shift to render H2O and x2. Builder/push snapshot rules apply.

ParagraphOptions.height_behavior exposes SkiaTextHeightBehavior:
All (default), DisableFirstAscent, DisableLastDescent, DisableAll. It controls native
first/last height expansion for a paragraph, particularly with text height overrides.
Both create_paragraph_builder overloads pass it, including strut builders. Native
strut/line-metric interactions remain native; flags do not promise ink clipping or
identical trimming for every configuration. Existing raw builder signatures are
preserved; the new raw layout adapter supplies the extra field.

All style settings copy into builders/paragraphs; no caller array/option pointer
escapes. Clear/reset on a source style affects future snapshots. The API does not
add a text-editing framework or require a different web implementation.

## Native inventory

ParagraphAddFontFace, NewParagraphBuilderLayout,
FontTag, FontTagName, FontAxisCount, FontAxis, ParagraphFontArguments,
ParagraphClearFontArguments, ParagraphDecoration, ParagraphAddShadow,
ParagraphResetShadows, ParagraphBaselineShift (all Skia_ prefixed).
These are C++ adapters, not a stable C ABI. Palette overrides, variable-font font-size
policy and automatic optical sizing are not exposed in this API.
