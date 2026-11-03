# SkParagraph hit testing and selection

`require dasskia/skia_paragraph` exports this API on desktop and WASM. It uses
SkParagraph's native hit testing, ICU word boundaries and range rectangles.
Positions use the paragraph top-left origin, before the canvas transform. Subtract
the origin passed to draw_paragraph from pointer coordinates first; also account
for canvas scaling/transforms in the caller. No SDL event loop is added.

## Hit test → word → selection

```das
let hit = paragraph |> paragraph_hit_test(local_point) |> skia_try
let word = paragraph |> paragraph_word_boundary_utf16(hit.position_utf16) |> skia_try
var boxes <- paragraph |> paragraph_rects_utf16(word.start_utf16,word.end_utf16) |> skia_try
for (box in boxes) {
    let r=box.rect
    canvas |> draw_rect(float4(r.x+origin.x,r.y+origin.y,r.z,r.w),highlight_paint)
}
canvas |> draw_paragraph(paragraph,origin)
```

Run `examples/selection.das` on desktop or select Text selection on the web page.
It supplies a deterministic probe point to demonstrate word selection, then draws
a second selection through combining marks, emoji, RTL runs and a newline. It is
a rendering/API example; it does not implement interactive editing or dragging.

## Index units and conversion

- `paragraph_text_length` returns ParagraphTextLength with utf8_bytes and
  utf16_units for the original concatenated builder text. Neither is a glyph,
  grapheme or display-column count. An astral scalar such as 😀 is 4 UTF-8 bytes
  and 2 UTF-16 code units. Combining marks are separate scalars, even within one
  grapheme. Newlines and all appended style runs contribute to global offsets.
- `paragraph_utf8_to_utf16(paragraph,byte_offset)` and
  `paragraph_utf16_to_utf8(paragraph,unit_offset)` return Result<int>. They accept
  scalar boundaries including zero and the exact end. Negative/out-of-bounds
  indices, interior UTF-8 bytes and the middle of a surrogate pair return Err.
  There is no rounding, clipping or grapheme normalization in conversions.
- Text length and conversion are available immediately after build, before layout.
  Mapping tables belong to the paragraph and survive builder/font-handle destruction.
- Geometry/word queries require layout_paragraph first. Repeated layout changes
  positions/rectangles, while text indices and mapping stay unchanged.

## Hit testing and affinity

`paragraph_hit_test(paragraph,float2)` returns Result<ParagraphHit> with
position_utf16, position_utf8 and native SkiaParagraphAffinity.Upstream/Downstream.
Affinity says which side of a text boundary the caret is associated with; it is
important at wraps and bidi boundaries. Do not infer it solely from RTL/LTR.
The UTF-16 position is native; the byte position is its exact scalar conversion.
A position is an insertion offset, not a glyph ID. Native hit testing chooses a
nearby caret for finite points outside paragraph bounds. NaN/infinity return Err.
An empty laid-out paragraph returns position zero with Downstream affinity.
This API does not calculate caret rectangles or movement/keyboard editing policy.

## Word boundaries

`paragraph_word_boundary_utf16(paragraph,unit_offset)` and the `_utf8` variant
return Result<ParagraphTextRange>: start_utf8/end_utf8/start_utf16/end_utf16.
Ranges are half-open. The offset must be a valid scalar boundary. At exact text
end, Skia returns the empty end range. ICU boundaries include punctuation and
whitespace segments; the result need not be a dictionary word or identifier.
SkParagraph's pinned getWordBoundary uses ICU's native default word locale;
TextStyle.locale is not a custom locale argument to this query.

## Range rectangles

`paragraph_rects_utf16(paragraph,start,end,ParagraphRectOptions())` and `_utf8`
return Result<array<ParagraphTextBox>>. Each box has paragraph-local XYWH rect and
native SkiaParagraphDirection. Native ordering is preserved; bidi ranges can
produce multiple LTR/RTL boxes on one line. Boxes are copied language values:
no borrowed spans, temporary native storage or fonts escape. An array remains
unchanged after relayout or paragraph destruction.

ParagraphRectOptions.height exposes native Tight, Max, IncludeLineSpacingMiddle,
IncludeLineSpacingTop, IncludeLineSpacingBottom and Strut; width exposes Tight/Max.
Defaults are Tight/Tight. These are layout rectangles, not tight ink bounds.

Selection preserves m138 SkParagraph's grapheme policy: it includes only complete
graphemes contained by the range. A scalar-valid range covering only the base `e`
of `é` can return no boxes. Strict scalar validation is separate from this native
policy. Empty ranges return an empty array. Reversed/out-of-bounds ranges or
half-surrogate endpoints return Err. The allowed range is the actual text, including
its end; the implied newline after empty text is not an extra selectable unit.
With ellipsis, indices still refer to original text; boxes describe the visible
layout and do not promise geometry for hidden text. Selection itself does not
paint highlights, mutate styles or select text. Draw the copied boxes behind text.

## Native inventory

Skia_ParagraphTextLength,
Skia_ParagraphUtf8ToUtf16, Skia_ParagraphUtf16ToUtf8, Skia_ParagraphHitTest,
Skia_ParagraphWordBoundaryUtf16, Skia_ParagraphRangeRectsUtf16,
Skia_DeleteParagraphRects, Skia_ParagraphRectCount, Skia_ParagraphRectAt.
The native-only SkiaParagraphRects pointer owns a geometry snapshot and is deleted
by the script copying helper with defer. Direct raw callers must delete it and
check RectAt bounds. It does not borrow the paragraph. These adapters have C++
linkage and do not constitute a stable C ABI.

[Grapheme navigation and caret geometry](caret-api.md) are available.
[Placeholders and strut](inline-layout-api.md) are also available.
[Text paints and font features](text-style-api.md) are also available.
[Font variations and typography controls](typography-api.md) are available.
Interactive editing remains caller policy.
