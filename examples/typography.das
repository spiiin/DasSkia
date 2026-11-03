options gen2
require dasskia/skia_paragraph
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var title,left_label,right_label,light,heavy,shadows,formula,height_label,trim_label,full_height,trim_height,footer : SkiaParagraph?
var decorated : array<SkiaParagraph?>
var frames : int
def typography_label(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; width : float; settings : ParagraphOptions = ParagraphOptions()) {
    return fonts |> with_paragraph_builder(style,settings) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        var built <- build_paragraph(builder)
        if (is_err(built)) { return <- built }
        var p=move_unwrap(built)
        var laid <- layout_paragraph(p,width)
        if (is_err(laid)) { destroy_paragraph(p); return err(unwrap_err(laid),type<SkiaParagraph?>) }
        return <- move_ok(p,type<SkiaError>)
    }
}

def initialize_typography() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · Variable fonts and typography",size=int2(900,760))) |> skia_try
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/Distortable.ttf","Variable") |> skia_try
        // Explicit TTC face 1 is the bundled DejaVu Sans face.
        fonts |> add_paragraph_font("assets/fonts/ExampleCollection.ttc","Demo",1) |> skia_try
        var demo <- array("Demo");var vf <- array("Variable")
        let heading : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=32.0,color=0xff50d99au)) |> skia_use
        let small : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=18.0,color=0xffb4c5d9u)) |> skia_use
        let body : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=48.0,color=0xffe8edf8u)) |> skia_use
        let script : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=28.0,color=0xffffb55du)) |> skia_use
        let variable : SkiaParagraphTextStyle? = with_paragraph_style(vf,ParagraphTextOptions(size=84.0,color=0xffe8edf8u)) |> skia_use
        let tall : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=20.0,color=0xffe8edf8u,height=2.0)) |> skia_use
        title=typography_label(fonts,heading,"Variable fonts and typography",800.0) |> skia_try
        left_label=typography_label(fonts,small,"Distortable: wght = 0.5",380.0) |> skia_try
        right_label=typography_label(fonts,small,"Distortable: wght = 2.0",380.0) |> skia_try
        var axes <- array(FontVariation(tag="wght",value=0.5))
        variable |> set_paragraph_font_arguments(axes) |> skia_try
        light=typography_label(fonts,variable,"abcabc",380.0) |> skia_try
        axes[0].value=2.0
        variable |> set_paragraph_font_arguments(axes) |> skia_try
        heavy=typography_label(fonts,variable,"abcabc",380.0) |> skia_try
        var names <- array("Solid","Double","Dotted","Dashed","Wavy")
        var styles <- array(SkiaTextDecorationStyle.Solid,SkiaTextDecorationStyle.Double,SkiaTextDecorationStyle.Dotted,SkiaTextDecorationStyle.Dashed,SkiaTextDecorationStyle.Wavy)
        for (i in 0 .. 5) {
            with_paragraph_style(demo,ParagraphTextOptions(size=28.0,color=0xffe8edf8u)) $(st : SkiaParagraphTextStyle?) {
                st |> set_paragraph_decoration(ParagraphDecorationOptions(bits=PARAGRAPH_UNDERLINE,color=0xff39b5f0u,style=styles[i],thickness=2.0,mode=SkiaTextDecorationMode.Through)) |> skia_try
                var entry=typography_label(fonts,st,names[i],145.0) |> skia_try
                push(decorated,entry)
                return skia_ok()
            } |> skia_try
        }
        body |> set_paragraph_decoration(ParagraphDecorationOptions(bits=PARAGRAPH_OVERLINE|PARAGRAPH_LINE_THROUGH,color=0xffffb55du,thickness=1.2)) |> skia_try
        body |> add_paragraph_shadow(ParagraphShadowOptions(color=0xffff5d62u,offset=float2(5.0,5.0))) |> skia_try
        body |> add_paragraph_shadow(ParagraphShadowOptions(color=0xff39b5f0u,offset=float2(-5.0,7.0),blur_sigma=2.0)) |> skia_try
        shadows=typography_label(fonts,body,"Shadow layers",430.0) |> skia_try
        body |> reset_paragraph_shadows();body |> set_paragraph_decoration(ParagraphDecorationOptions()) |> skia_try
        let b : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(body,ParagraphOptions()) |> skia_use
        b |> add_paragraph_text("H") |> skia_try
        script |> set_paragraph_baseline_shift(10.0) |> skia_try
        b |> push_paragraph_style(script) |> skia_try;b |> add_paragraph_text("2") |> skia_try;b |> pop_paragraph_style() |> skia_try
        b |> add_paragraph_text("O + x") |> skia_try
        script |> set_paragraph_baseline_shift(-16.0) |> skia_try
        b |> push_paragraph_style(script) |> skia_try;b |> add_paragraph_text("2") |> skia_try;b |> pop_paragraph_style() |> skia_try
        formula=build_paragraph(b) |> skia_try
        formula |> layout_paragraph(340.0) |> skia_try
        height_label=typography_label(fonts,small,"Height: full first/last metrics",380.0) |> skia_try
        trim_label=typography_label(fonts,small,"Height: first/last expansion disabled",380.0) |> skia_try
        full_height=typography_label(fonts,tall,"First line\nLast line",380.0) |> skia_try
        trim_height=typography_label(fonts,tall,"First line\nLast line",380.0,ParagraphOptions(height_behavior=SkiaTextHeightBehavior.DisableAll)) |> skia_try
        footer=typography_label(fonts,small,"The pinned variable test font covers a/b/c only. UI text uses TTC face 1 (DejaVu Sans).\nAxis names and ranges come from the loaded font; unknown axes keep native behavior.",800.0) |> skia_try
        return skia_ok()
    }
}
def report_typography(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return -1 }
    return 0
}
[export]
def app_init() : int { return report_typography(initialize_typography()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_paragraph(title,float2(50.0,20.0))
        c |> draw_paragraph(left_label,float2(50.0,85.0));c |> draw_paragraph(right_label,float2(470.0,85.0))
        c |> draw_paragraph(light,float2(50.0,120.0));c |> draw_paragraph(heavy,float2(470.0,120.0))
        for (i in 0 .. length(decorated)) { c |> draw_paragraph(decorated[i],float2(50.0+float(i)*160.0,275.0)) }
        c |> draw_paragraph(shadows,float2(50.0,385.0));c |> draw_paragraph(formula,float2(520.0,385.0))
        c |> draw_paragraph(height_label,float2(50.0,510.0));c |> draw_paragraph(trim_label,float2(470.0,510.0))
        c |> draw_paragraph(full_height,float2(50.0,550.0));c |> draw_paragraph(trim_height,float2(470.0,550.0))
        c |> draw_paragraph(footer,float2(50.0,670.0))
        return skia_ok()
    }
    frames++
    if (frames==3) { print("PASS typography frame 3; decorations={length(decorated)}\n") }
    return report_typography(result)
}
[export]
def app_quit() {
    destroy_paragraph(title);title=null
    destroy_paragraph(left_label);left_label=null
    destroy_paragraph(right_label);right_label=null
    destroy_paragraph(light);light=null
    destroy_paragraph(heavy);heavy=null
    destroy_paragraph(shadows);shadows=null
    destroy_paragraph(formula);formula=null
    destroy_paragraph(height_label);height_label=null
    destroy_paragraph(trim_label);trim_label=null
    destroy_paragraph(full_height);full_height=null
    destroy_paragraph(trim_height);trim_height=null
    destroy_paragraph(footer);footer=null
    for (p in decorated) { destroy_paragraph(p) }
    clear(decorated)
    destroy_window(window);window=null
}
