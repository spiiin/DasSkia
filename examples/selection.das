options gen2
require dasskia/skia_paragraph
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var title,body,note : SkiaParagraph?
var highlight,marker : SkPaint?
var word_boxes,range_boxes : array<ParagraphTextBox>
var probe : float2
var frames : int

def selection_label(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; width : float) {
    return fonts |> with_paragraph_builder(style,ParagraphOptions()) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        var built <- build_paragraph(builder)
        if (is_err(built)) { return <- built }
        var p=move_unwrap(built)
        var laid <- layout_paragraph(p,width)
        if (is_err(laid)) { destroy_paragraph(p); return err(unwrap_err(laid),type<SkiaParagraph?>) }
        return <- move_ok(p,type<SkiaError>)
    }
}
def initialize_selection() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · Selection and hit testing",size=int2(900,580))) |> skia_try
    highlight=create_paint(PaintOptions(color=0xff294e70u))
    marker=create_paint(PaintOptions(color=0xffffb55du))
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let heading : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=34.0,color=0xff50d99au)) |> skia_use
        let regular : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=25.0,color=0xffe8edf8u,height=1.5)) |> skia_use
        let small : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=19.0,color=0xffb4c5d9u,height=1.5)) |> skia_use
        title=selection_label(fonts,heading,"Hit testing and selection",800.0) |> skia_try
        let content="office • é • 😀 • Привет • שלום עולם\nLatin and RTL share the same selection API.\nSelect across lines and bidi runs."
        body=selection_label(fonts,regular,content,800.0) |> skia_try
        // Known source range only locates this demo's probe. A UI would supply
        // its mouse position after subtracting the draw_paragraph origin.
        var target <- body |> paragraph_rects_utf8(0,6) |> skia_try
        let first=target[0].rect
        probe=float2(first.x+first.z*0.4,first.y+first.w*0.5)
        let hit=body |> paragraph_hit_test(probe) |> skia_try
        let word=body |> paragraph_word_boundary_utf16(hit.position_utf16) |> skia_try
        word_boxes <- body |> paragraph_rects_utf16(word.start_utf16,word.end_utf16) |> skia_try
        // Byte offsets come from source strings, not glyph or character counts.
        let prefix="office • "
        let selected="é • 😀 • Привет • שלום עולם\nLatin and RTL"
        range_boxes <- body |> paragraph_rects_utf8(length(prefix),length(prefix)+length(selected)) |> skia_try
        note=selection_label(fonts,small,
            "Orange probe → hit-test → word boundary → copied selection boxes.\nBlue selection crosses combining marks, emoji, RTL runs and a newline.\nThe rectangles use paragraph-local XYWH coordinates.\nHit position: UTF-8 byte {hit.position_utf8}, UTF-16 unit {hit.position_utf16}.\nWord: UTF-8 [{word.start_utf8}, {word.end_utf8}); UTF-16 [{word.start_utf16}, {word.end_utf16}).",800.0) |> skia_try
        return skia_ok()
    }
}
def report_selection(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return report_selection(initialize_selection()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_paragraph(title,float2(50.0,30.0))
        for (box in range_boxes) {
            let r=box.rect
            c |> draw_rect(float4(r.x+50.0,r.y+150.0,r.z,r.w),highlight)
        }
        for (box in word_boxes) {
            let r=box.rect
            c |> draw_rect(float4(r.x+50.0,r.y+150.0,r.z,r.w),highlight)
        }
        c |> draw_paragraph(body,float2(50.0,150.0))
        c |> draw_circle(probe+float2(50.0,150.0),4.0,marker)
        c |> draw_paragraph(note,float2(50.0,335.0))
        return skia_ok()
    }
    frames++
    if (frames==3) { print("PASS selection frame 3; word_boxes={length(word_boxes)}; range_boxes={length(range_boxes)}\n") }
    return report_selection(result)
}
[export]
def app_quit() {
    destroy_paragraph(title); title=null
    destroy_paragraph(body); body=null
    destroy_paragraph(note); note=null
    Skia_DeletePaint(highlight); highlight=null
    Skia_DeletePaint(marker); marker=null
    destroy_window(window); window=null
    clear(word_boxes); clear(range_boxes)
}
