options gen2
require dasskia/skia_paragraph
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var article : SkiaParagraph?
var summary : SkiaParagraph?
var rtl : SkiaParagraph?
var frames : int

def initialize_paragraph() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · SkParagraph",size=int2(900,680))) |> skia_try
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let body : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=23.0,color=0xffe8edf8u,height=1.3)) |> skia_use
        let heading : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=38.0,color=0xff50d99au)) |> skia_use
        let emphasis : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=23.0,color=0xffffb55du,decorations=PARAGRAPH_UNDERLINE)) |> skia_use
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body,ParagraphOptions()) |> skia_use
        builder |> push_paragraph_style(heading) |> skia_try
        builder |> add_paragraph_text("SkParagraph\n") |> skia_try
        builder |> pop_paragraph_style() |> skia_try
        builder |> add_paragraph_text("One paragraph, several styles. ") |> skia_try
        builder |> push_paragraph_style(emphasis) |> skia_try
        builder |> add_paragraph_text("Explicit file-backed fonts") |> skia_try
        builder |> pop_paragraph_style() |> skia_try
        builder |> add_paragraph_text(" with the same FreeType, HarfBuzz and ICU pipeline on desktop and web.\n\nПривет, мир! • office / ffi / á\nالعربية 123 • שלום עולם 456\n\nText wraps at the layout width. Call layout_paragraph again to reflow the same object.") |> skia_try
        article=build_paragraph(builder) |> skia_try
        article |> layout_paragraph(800.0) |> skia_try
        let limited : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body,ParagraphOptions(max_lines=2,ellipsis="…")) |> skia_use
        limited |> add_paragraph_text("Two lines with ellipsis. SkParagraph truncates this long description at a shaping boundary while keeping all text and styles in the paragraph. The remaining words do not fit in the available space.") |> skia_try
        summary=build_paragraph(limited) |> skia_try
        summary |> layout_paragraph(800.0) |> skia_try
        let right : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body,ParagraphOptions(direction=SkiaParagraphDirection.RTL)) |> skia_use
        right |> add_paragraph_text("السلام عليكم — שלום עולם") |> skia_try
        rtl=build_paragraph(right) |> skia_try
        rtl |> layout_paragraph(800.0) |> skia_try
        return skia_ok()
    }
}
def report_paragraph(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return report_paragraph(initialize_paragraph()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_paragraph(article,float2(50.0,35.0))
        c |> draw_paragraph(summary,float2(50.0,455.0))
        c |> draw_paragraph(rtl,float2(50.0,585.0))
        return skia_ok()
    }
    frames++
    if (frames==3) {
        var m <- paragraph_metrics(summary)
        if (is_ok(m)) { let value=unwrap(m); print("PASS paragraph frame 3; lines={value.lines}; ellipsis={value.exceeded_max_lines}; missing={value.unresolved_glyphs}\n") }
    }
    return report_paragraph(result)
}
[export]
def app_quit() {
    destroy_paragraph(article); article=null
    destroy_paragraph(summary); summary=null
    destroy_paragraph(rtl); rtl=null
    destroy_window(window); window=null
}
