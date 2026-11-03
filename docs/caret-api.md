# Grapheme navigation and caret geometry

`require dasskia/skia_paragraph` provides ICU grapheme navigation, copied native
SkParagraph GlyphInfo and an affinity-based caret-edge adapter on desktop and WASM.

```das
let step=paragraph |> paragraph_grapheme_boundary_utf16(position) |> skia_try
// Strictly next logical grapheme boundary; clamps to text end.
let next_position=step.next_utf16
let geometry=paragraph |> paragraph_caret_utf16(next_position,
    SkiaParagraphAffinity.Upstream) |> skia_try
if (is_some(geometry)) {
    let edge=unwrap(geometry).rect
    canvas |> draw_rect(float4(edge.x+origin.x,edge.y+origin.y,2.0,edge.w),paint)
}
```

See [examples/caret.das](../examples/caret.das): orange edges for combining text,
emoji and RTL, and orange/green Upstream/Downstream edges on a soft wrap.

## ICU boundaries

`paragraph_grapheme_boundary_utf16(paragraph,position)` and `_utf8` return
Result<ParagraphGraphemeBoundary> with is_boundary and previous/next offsets in both
encodings. Input must be a scalar boundary, as in the selection API. It may be inside
a grapheme (for example between base and combining mark). Previous/next are strictly
before/after the input and clamp to start/end; an empty paragraph has only boundary 0.

Boundaries are extracted once from the original concatenated builder text using
the pinned ICU SkUnicode grapheme iterator. They are available before layout and
survive reflow/font-handle destruction. This is logical Unicode navigation, not
visual left/right bidi navigation or a keyboard editing framework. ZWJ emoji and
regional-indicator grouping do not require the loaded font to cover those glyphs.

## Native grapheme geometry

`paragraph_grapheme_info_utf16` and `_utf8` return
Result<Option<ParagraphGraphemeInfo>>. The copied value contains ParagraphTextRange
in both encodings, paragraph-local XYWH rect, direction and native is_ellipsis.
An input scalar may be inside a grapheme; the returned range is the whole native
grapheme. Layout is required. Invalid indices/pre-layout queries return Err;
end-of-text, empty or unavailable/hidden geometry returns Ok(None).

The native m138 method can report success without filling GlyphInfo for some
clusters; the adapter initializes its output and returns None if no range was
filled. It preserves actual zero-width geometry when provided (for example a
newline). Rectangles are layout bounds, not ink bounds. Ranges and geometry are
copied, retain no pointers and are not updated by later layout.

## Caret-edge adapter

`paragraph_caret_utf16(paragraph,position,affinity=Downstream)` and `_utf8` return
Result<Option<ParagraphCaret>>. Input must be an ICU grapheme boundary; scalar-valid
positions inside a grapheme return Err. The value contains both index units,
affinity, direction and a zero-width XYWH rectangle. The caller chooses stroke
width, clipping, color and origin when painting.

Downstream selects the following grapheme's leading edge. Upstream selects the
preceding grapheme's trailing edge. For RTL, leading is its right edge and trailing
its left edge. At a soft wrap the same logical position can therefore have geometry
on either line. At a bidi boundary the two affinities can choose different visual
edges. The adapter uses native tight grapheme bounds, not full line-height boxes.

No adjacent grapheme for the requested affinity means None: start+Upstream,
end+Downstream and empty text. Hidden/missing geometry, ellipsis and zero-width or
zero-height clusters also return None. There is no synthesized newline/empty-line
caret or automatic fallback to the other affinity. ICU boundaries include original
hidden text; navigation does not imply a visible caret. This is a documented
geometry adapter, not a native SkParagraph cursor/editing API. It does not implement
visual bidi arrow policy, vertical navigation, selection movement or editing.

## Inventory

Native adapters:
Skia_ParagraphGraphemeBoundaryUtf16, Skia_ParagraphGraphemeInfoUtf16,
Skia_ParagraphCaretUtf16. They use C++ linkage, not a stable C ABI.

[Placeholders and strut](inline-layout-api.md) are available.
[Text paints and font features](text-style-api.md) are also available.
[Font variations and typography controls](typography-api.md) are available.
Interactive editing remains caller policy.
