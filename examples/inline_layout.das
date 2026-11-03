options gen2
require dasskia/skia_paragraph
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var title,note,flow,normal,fixed,left_label,right_label : SkiaParagraph?
var objects : array<ParagraphTextBox>
var blue,orange,green,white,guide : SkPaint?
var frames : int

def inline_label(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; width : float; strut : SkiaParagraphStrut? = null) {
    return fonts |> with_paragraph_builder(style,strut,ParagraphOptions()) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        var created <- build_paragraph(builder)
        if (is_err(created)) { return <- created }
        var p=move_unwrap(created)
        var laid <- layout_paragraph(p,width)
        if (is_err(laid)) { destroy_paragraph(p); return err(unwrap_err(laid),type<SkiaParagraph?>) }
        return <- move_ok(p,type<SkiaError>)
    }
}
def initialize_inline() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · Placeholders and strut",size=int2(900,680))) |> skia_try
    blue=create_paint(PaintOptions(color=0xff39b5f0u))
    orange=create_paint(PaintOptions(color=0xffffb55du))
    green=create_paint(PaintOptions(color=0xff50d99au))
    white=create_paint(PaintOptions(color=0xffe8edf8u))
    guide=create_paint(PaintOptions(color=0xff294e70u))
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let heading : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=34.0,color=0xff50d99au)) |> skia_use
        let body : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=24.0,color=0xffe8edf8u)) |> skia_use
        let small : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=20.0,color=0xffb4c5d9u)) |> skia_use
        let strut_font : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=32.0)) |> skia_use
        let strut : SkiaParagraphStrut? = strut_font |> with_paragraph_strut(ParagraphStrutOptions(height=1.5,height_override=true,force_height=true)) |> skia_use
        title=inline_label(fonts,heading,"Placeholders and strut",800.0) |> skia_try
        note=inline_label(fonts,small,"Skia lays out inline objects. The application draws their contents.",800.0) |> skia_try
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body,ParagraphOptions()) |> skia_use
        builder |> add_paragraph_text("Text before ") |> skia_try
        builder |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(48.0,36.0),baseline_offset=30.0)) |> skia_try
        builder |> add_paragraph_text(" and an inline badge ") |> skia_try
        builder |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(92.0,30.0),alignment=SkiaPlaceholderAlignment.Middle)) |> skia_try
        builder |> add_paragraph_text(".\nIcons and badges participate in wrapping.\nאב ") |> skia_try
        builder |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(32.0,32.0),baseline_offset=26.0)) |> skia_try
        builder |> add_paragraph_text(" גד — RTL runs share the same model.") |> skia_try
        flow=build_paragraph(builder) |> skia_try
        flow |> layout_paragraph(800.0) |> skia_try
        objects <- flow |> paragraph_placeholder_rects() |> skia_try
        normal=inline_label(fonts,small,"Small text\nSame font, three lines\nNative line spacing",350.0) |> skia_try
        fixed=inline_label(fonts,small,"Small text\nSame font, three lines\nStrut sets a 48 px grid",350.0,strut) |> skia_try
        left_label=inline_label(fonts,body,"Default line height",350.0) |> skia_try
        right_label=inline_label(fonts,body,"Strut: 48 px line grid",350.0) |> skia_try
        return skia_ok()
    }
}
def report_inline(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return report_inline(initialize_inline()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_paragraph(title,float2(50.0,30.0))
        c |> draw_paragraph(note,float2(50.0,90.0))
        c |> draw_paragraph(flow,float2(50.0,155.0))
        for (i in 0 .. length(objects)) {
            let r=objects[i].rect
            var paint=blue
            if (i==1) { paint=orange }
            if (i==2) { paint=green }
            c |> draw_rect(float4(r.x+50.0,r.y+155.0,r.z,r.w),paint)
            if (i==0) { c |> draw_circle(float2(r.x+74.0,r.y+173.0),10.0,white) }
            if (i==1) { c |> draw_rect(float4(r.x+60.0,r.y+165.0,r.z-20.0,4.0),white) }
        }
        c |> draw_paragraph(left_label,float2(50.0,355.0))
        c |> draw_paragraph(right_label,float2(470.0,355.0))
        for (i in 0 .. 3) {
            let y=410.0+float(i)*48.0
            c |> draw_rect(float4(465.0,y,365.0,1.0),guide)
        }
        c |> draw_paragraph(normal,float2(50.0,410.0))
        c |> draw_paragraph(fixed,float2(470.0,410.0))
        return skia_ok()
    }
    frames++
    if (frames==3) { print("PASS inline layout frame 3; objects={length(objects)}\n") }
    return report_inline(result)
}
[export]
def app_quit() {
    destroy_paragraph(title); title=null
    destroy_paragraph(note); note=null
    destroy_paragraph(flow); flow=null
    destroy_paragraph(normal); normal=null
    destroy_paragraph(fixed); fixed=null
    destroy_paragraph(left_label); left_label=null
    destroy_paragraph(right_label); right_label=null
    Skia_DeletePaint(blue); blue=null
    Skia_DeletePaint(orange); orange=null
    Skia_DeletePaint(green); green=null
    Skia_DeletePaint(white); white=null
    Skia_DeletePaint(guide); guide=null
    destroy_window(window); window=null
    clear(objects)
}
