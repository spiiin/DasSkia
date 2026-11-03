options gen2
require dasskia/skia_paragraph
require dasskia/skia_sdl_gl
require dasskia/skia_scope
require math

var window : SkiaWindow?
var title,body,note : SkiaParagraph?
var outline,orange,green : SkPaint?
var edges : array<ParagraphCaret>
var wrap_up,wrap_down : ParagraphCaret
var has_wrap : bool
var frames : int
def caret_label(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; width : float) {
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

def initialize_caret() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · Graphemes and carets",size=int2(900,580))) |> skia_try
    outline=create_paint(PaintOptions(color=0xff294e70u))
    orange=create_paint(PaintOptions(color=0xffffb55du))
    green=create_paint(PaintOptions(color=0xff50d99au))
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let heading : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=34.0,color=0xff50d99au)) |> skia_use
        let regular : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=28.0,color=0xffe8edf8u)) |> skia_use
        let small : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=20.0,color=0xffb4c5d9u,height=1.4)) |> skia_use
        title=caret_label(fonts,heading,"Grapheme geometry and carets",800.0) |> skia_try
        body=caret_label(fonts,regular,"office • á • 😀 • שלום\nA soft wrap can give one logical position two visual caret edges. ICU navigation keeps combining marks and emoji together.",430.0) |> skia_try
        var positions <- array(length("office • "),length("office • á"),length("office • á • "),length("office • á • 😀"),length("office • á • 😀 • "))
        for (i in 0 .. length(positions)) {
            var affinity=SkiaParagraphAffinity.Downstream
            if (i==1 || i==3) { affinity=SkiaParagraphAffinity.Upstream }
            let caret=body |> paragraph_caret_utf8(positions[i],affinity) |> skia_try
            if (is_some(caret)) { push(edges,unwrap(caret)) }
        }
        var i=0
        while (i<paragraph_text_length(body).utf16_units) {
            let b=body |> paragraph_grapheme_boundary_utf16(i) |> skia_try
            let up=body |> paragraph_caret_utf16(i,SkiaParagraphAffinity.Upstream) |> skia_try
            let down=body |> paragraph_caret_utf16(i) |> skia_try
            if (is_some(up) && is_some(down) && abs(unwrap(up).rect.y-unwrap(down).rect.y)>1.0 && !has_wrap) {
                wrap_up=unwrap(up); wrap_down=unwrap(down); has_wrap=true
            }
            i=b.next_utf16
        }
        note=caret_label(fonts,small,"Orange: edges of á, emoji and RTL graphemes.\n\nAt the soft wrap, orange is Upstream and green is Downstream.\n\nNavigation follows logical ICU boundaries. Visual bidi arrow movement is an application policy.",330.0) |> skia_try
        return skia_ok()
    }
}
def report_caret(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return report_caret(initialize_caret()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_paragraph(title,float2(50.0,30.0))
        c |> draw_rect(float4(45.0,135.0,440.0,235.0),outline)
        c |> draw_paragraph(body,float2(50.0,140.0))
        c |> draw_paragraph(note,float2(520.0,140.0))
        for (edge in edges) {
            let r=edge.rect
            c |> draw_rect(float4(r.x+50.0,r.y+140.0,2.0,r.w),orange)
        }
        if (has_wrap) {
            let u=wrap_up.rect; let d=wrap_down.rect
            c |> draw_rect(float4(u.x+50.0,u.y+140.0,3.0,u.w),orange)
            c |> draw_rect(float4(d.x+50.0,d.y+140.0,3.0,d.w),green)
        }
        return skia_ok()
    }
    frames++
    if (frames==3) { print("PASS caret frame 3; edges={length(edges)}; wrap={has_wrap}\n") }
    return report_caret(result)
}
[export]
def app_quit() {
    destroy_paragraph(title); title=null
    destroy_paragraph(body); body=null
    destroy_paragraph(note); note=null
    Skia_DeletePaint(outline); outline=null
    Skia_DeletePaint(orange); orange=null
    Skia_DeletePaint(green); green=null
    destroy_window(window); window=null
    clear(edges)
}
