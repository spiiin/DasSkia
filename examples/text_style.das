options gen2
require dasskia/skia_paragraph
require dasskia/skia_effects
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var title,note,gradient_text,outline_text,on_text,off_text,on_label,off_label,on_metrics,off_metrics : SkiaParagraph?
var blue,orange : SkPaint?
var on_width,off_width : float
var frames : int
def painted_label(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; width : float) {
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

def initialize_text_style() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · Text paints and OpenType",size=int2(900,680))) |> skia_try
    blue=create_paint(PaintOptions(color=0xff39b5f0u))
    orange=create_paint(PaintOptions(color=0xffffb55du))
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let heading : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=34.0,color=0xff50d99au)) |> skia_use
        let small : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=18.0,color=0xffb4c5d9u,height=1.4)) |> skia_use
        let display : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=72.0,color=0xffffffffu)) |> skia_use
        let outline_style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=64.0)) |> skia_use
        let feature_style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=64.0,color=0xffe8edf8u)) |> skia_use
        let foreground : SkPaint? = with_paint(PaintOptions(color=0xffffffffu)) |> skia_use
        let background : SkPaint? = with_paint(PaintOptions(color=0xff294e70u)) |> skia_use
        let stroke : SkPaint? = with_paint(PaintOptions(color=0xffffb55du,stroke=true,stroke_width=1.5)) |> skia_use
        var colors <- array(0xff39b5f0u,0xffffb55du)
        let shader : SkShader? = linear_gradient(float2(0.0),float2(500.0,0.0),colors) |> with_shader() |> skia_use
        foreground |> set_shader(shader)
        display |> set_paragraph_foreground(foreground)
        display |> set_paragraph_background(background)
        outline_style |> set_paragraph_foreground(stroke)
        background |> set_color(0xff293247u)
        outline_style |> set_paragraph_background(background)
        title=painted_label(fonts,heading,"Text paints and OpenType features",800.0) |> skia_try
        note=painted_label(fonts,small,"SkPaint foreground/background, gradient fill and stroke. One API on desktop and web.",800.0) |> skia_try
        gradient_text=painted_label(fonts,display,"Painted text",800.0) |> skia_try
        outline_text=painted_label(fonts,outline_style,"Outlined glyphs",800.0) |> skia_try
        feature_style |> add_paragraph_font_feature("liga",1) |> skia_try
        feature_style |> add_paragraph_font_feature("kern",1) |> skia_try
        on_text=painted_label(fonts,feature_style,"ffi AVATAR",380.0) |> skia_try
        feature_style |> reset_paragraph_font_features()
        feature_style |> add_paragraph_font_feature("liga",0) |> skia_try
        feature_style |> add_paragraph_font_feature("kern",0) |> skia_try
        off_text=painted_label(fonts,feature_style,"ffi AVATAR",380.0) |> skia_try
        let enabled=paragraph_metrics(on_text) |> skia_try
        let disabled=paragraph_metrics(off_text) |> skia_try
        on_width=enabled.longest_line; off_width=disabled.longest_line
        on_label=painted_label(fonts,small,"liga=1 / kern=1",380.0) |> skia_try
        off_label=painted_label(fonts,small,"liga=0 / kern=0",380.0) |> skia_try
        on_metrics=painted_label(fonts,small,"Advance: {on_width} px\nThe line marks the measured advance.",380.0) |> skia_try
        off_metrics=painted_label(fonts,small,"Advance: {off_width} px\nFeature support depends on the loaded font.",380.0) |> skia_try
        return skia_ok()
    }
}
def report_text_style(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return report_text_style(initialize_text_style()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_paragraph(title,float2(50.0,25.0))
        c |> draw_paragraph(note,float2(50.0,80.0))
        c |> draw_paragraph(gradient_text,float2(50.0,130.0))
        c |> draw_paragraph(outline_text,float2(50.0,245.0))
        c |> draw_paragraph(on_label,float2(50.0,365.0))
        c |> draw_paragraph(off_label,float2(470.0,365.0))
        c |> draw_paragraph(on_text,float2(50.0,405.0))
        c |> draw_paragraph(off_text,float2(470.0,405.0))
        c |> draw_rect(float4(50.0,495.0,on_width,3.0),blue)
        c |> draw_rect(float4(470.0,495.0,off_width,3.0),orange)
        c |> draw_paragraph(on_metrics,float2(50.0,525.0))
        c |> draw_paragraph(off_metrics,float2(470.0,525.0))
        return skia_ok()
    }
    frames++
    if (frames==3) { print("PASS text style frame 3; on_width={on_width}; off_width={off_width}\n") }
    return report_text_style(result)
}
[export]
def app_quit() {
    destroy_paragraph(title); title=null
    destroy_paragraph(note); note=null
    destroy_paragraph(gradient_text); gradient_text=null
    destroy_paragraph(outline_text); outline_text=null
    destroy_paragraph(on_text); on_text=null
    destroy_paragraph(off_text); off_text=null
    destroy_paragraph(on_label); on_label=null
    destroy_paragraph(off_label); off_label=null
    destroy_paragraph(on_metrics); on_metrics=null
    destroy_paragraph(off_metrics); off_metrics=null
    Skia_DeletePaint(blue); blue=null
    Skia_DeletePaint(orange); orange=null
    destroy_window(window); window=null
}
