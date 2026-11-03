options gen2
require dasskia/skia_paragraph
require dasskia/skia_effects
require dasskia/skia_scope
require math

def check_style(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("text_style_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def styled_text(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string) {
    return fonts |> with_paragraph_builder(style,ParagraphOptions()) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        return <- build_paragraph(builder)
    }
}
def retained_painted_text() {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=64.0,color=0xff00ff00u)) |> skia_use
        let foreground : SkPaint? = with_paint(PaintOptions(color=0xffffffffu)) |> skia_use
        let background : SkPaint? = with_paint(PaintOptions(color=0xff204030u)) |> skia_use
        var colors <- array(0xffff2020u,0xff2020ffu)
        let shader : SkShader? = linear_gradient(float2(0.0),float2(320.0,0.0),colors) |> with_shader() |> skia_use
        foreground |> set_shader(shader)
        style |> set_paragraph_foreground(foreground)
        style |> set_paragraph_background(background)
        // Style already copied both paints and retained the shader.
        foreground |> set_shader()
        foreground |> set_color(0xff00ff00u)
        background |> set_color(0xffff0000u)
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(style,ParagraphOptions()) |> skia_use
        // Builder already copied the complete style; these changes affect future uses.
        style |> set_paragraph_foreground()
        style |> set_paragraph_background()
        style |> add_paragraph_font_feature("liga",0) |> skia_try
        builder |> add_paragraph_text("MMMMMM") |> skia_try
        return <- build_paragraph(builder)
    }
}
def test_text_style() : SkiaStatus {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=64.0,color=0xffffffffu)) |> skia_use
        check_style(is_err(add_paragraph_font_feature(style,"lig",0)) && is_err(add_paragraph_font_feature(style,"ligaa",0)) &&
            is_err(add_paragraph_font_feature(style,"éé",1)) && is_err(add_paragraph_font_feature(style,"a\nbc",1)) &&
            is_err(add_paragraph_font_feature(style,"liga",-1)),"invalid tags and values") |> skia_try
        for (i in 0 .. 256) { style |> add_paragraph_font_feature("zzzz",0) |> skia_try }
        check_style(is_err(add_paragraph_font_feature(style,"liga",0)),"feature limit") |> skia_try
        style |> reset_paragraph_font_features()
        let default_ffi : SkiaParagraph? = styled_text(fonts,style,"ffi") |> with_paragraph() |> skia_use
        let default_av : SkiaParagraph? = styled_text(fonts,style,"AV") |> with_paragraph() |> skia_use
        style |> add_paragraph_font_feature("liga",0) |> skia_try
        let plain_ffi : SkiaParagraph? = styled_text(fonts,style,"ffi") |> with_paragraph() |> skia_use
        style |> add_paragraph_font_feature("kern",0) |> skia_try
        let plain_av : SkiaParagraph? = styled_text(fonts,style,"AV") |> with_paragraph() |> skia_use
        style |> reset_paragraph_font_features()
        let reset : SkiaParagraph? = styled_text(fonts,style,"ffi") |> with_paragraph() |> skia_use
        style |> add_paragraph_font_feature("zzzz",1) |> skia_try
        let unknown : SkiaParagraph? = styled_text(fonts,style,"ffi") |> with_paragraph() |> skia_use
        default_ffi |> layout_paragraph(500.0) |> skia_try
        plain_ffi |> layout_paragraph(500.0) |> skia_try
        default_av |> layout_paragraph(500.0) |> skia_try
        plain_av |> layout_paragraph(500.0) |> skia_try
        reset |> layout_paragraph(500.0) |> skia_try
        unknown |> layout_paragraph(500.0) |> skia_try
        let lig=paragraph_metrics(default_ffi) |> skia_try
        let no_lig=paragraph_metrics(plain_ffi) |> skia_try
        let kern=paragraph_metrics(default_av) |> skia_try
        let no_kern=paragraph_metrics(plain_av) |> skia_try
        let restored=paragraph_metrics(reset) |> skia_try
        let ignored=paragraph_metrics(unknown) |> skia_try
        check_style(abs(lig.longest_line-no_lig.longest_line)>0.1,"liga changes real shaping") |> skia_try
        check_style(kern.longest_line<no_kern.longest_line-1.0,"kern changes real shaping") |> skia_try
        check_style(abs(lig.longest_line-restored.longest_line)<0.01 && abs(lig.longest_line-ignored.longest_line)<0.01,"reset restores defaults and unknown features remain native no-op") |> skia_try
        // Feature entries retain native order; later entries for a tag take precedence in HarfBuzz.
        style |> reset_paragraph_font_features()
        style |> add_paragraph_font_feature("liga",0) |> skia_try
        style |> add_paragraph_font_feature("liga",1) |> skia_try
        let duplicate : SkiaParagraph? = styled_text(fonts,style,"ffi") |> with_paragraph() |> skia_use
        duplicate |> layout_paragraph(500.0) |> skia_try
        let dup=paragraph_metrics(duplicate) |> skia_try
        check_style(abs(dup.longest_line-lig.longest_line)<0.01,"duplicate tag order") |> skia_try
        style |> reset_paragraph_font_features()
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(style,ParagraphOptions()) |> skia_use
        builder |> push_paragraph_style(style) |> skia_try
        style |> add_paragraph_font_feature("liga",0) |> skia_try
        builder |> add_paragraph_text("ffi") |> skia_try
        builder |> pop_paragraph_style() |> skia_try
        let copied : SkiaParagraph? = build_paragraph(builder) |> with_paragraph() |> skia_use
        copied |> layout_paragraph(500.0) |> skia_try
        let copy=paragraph_metrics(copied) |> skia_try
        check_style(abs(copy.longest_line-lig.longest_line)<0.01,"pushed styles snapshot features") |> skia_try
        let rich : SkiaParagraph? = retained_painted_text() |> with_paragraph() |> skia_use
        rich |> layout_paragraph(500.0) |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(500,280))) |> skia_use
        let c=canvas(surface)
        c |> clear(0xff000000u)
        c |> draw_paragraph(rich,float2(10.0,10.0))
        var red,blue,bg,unexpected_green : int
        for (y in 10 .. 100) {
            for (x in 10 .. 450) {
                let pixel=surface |> read_pixel(int2(x,y)) |> skia_try
                let r=(pixel>>16)&255u; let g=(pixel>>8)&255u; let b=pixel&255u
                if (r>100u && r>b+40u && r>g+40u) { red++ }
                if (b>100u && b>r+40u && b>g+40u) { blue++ }
                if (pixel==0xff204030u) { bg++ }
                if (g>200u && r<30u && b<30u) { unexpected_green++ }
            }
        }
        check_style(red>300 && blue>300 && bg>1000 && unexpected_green==0,"paint/shader/font/style ownership and copied background") |> skia_try
        let outline_style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=96.0,color=0xff50d99au)) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xff50d99au,stroke=true,stroke_width=1.5)) |> skia_use
        outline_style |> set_paragraph_foreground(paint)
        let outline : SkiaParagraph? = styled_text(fonts,outline_style,"O") |> with_paragraph() |> skia_use
        paint |> set_stroke(false)
        outline_style |> set_paragraph_background(paint)
        outline_style |> set_paragraph_foreground()
        outline_style |> set_paragraph_background()
        let filled : SkiaParagraph? = styled_text(fonts,outline_style,"O") |> with_paragraph() |> skia_use
        outline |> layout_paragraph(180.0) |> skia_try
        filled |> layout_paragraph(180.0) |> skia_try
        c |> draw_paragraph(outline,float2(10.0,130.0))
        c |> draw_paragraph(filled,float2(190.0,130.0))
        var thin,solid : int
        for (y in 130 .. 270) {
            for (x in 10 .. 160) {
                let a=surface |> read_pixel(int2(x,y)) |> skia_try
                let b=surface |> read_pixel(int2(x+180,y)) |> skia_try
                if (a!=0xff000000u) { thin++ }
                if (b!=0xff000000u) { solid++ }
            }
        }
        check_style(thin>100 && float(thin)<float(solid)*0.7,"stroke foreground and null reset to style color without background") |> skia_try
        // The native m138 spacing policy disables liga when positive letter spacing is set.
        let spaced_style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=64.0,letter_spacing=2.0)) |> skia_use
        spaced_style |> add_paragraph_font_feature("liga",1) |> skia_try
        let spaced : SkiaParagraph? = styled_text(fonts,spaced_style,"ffi") |> with_paragraph() |> skia_use
        spaced |> layout_paragraph(500.0) |> skia_try
        let spacing=paragraph_metrics(spaced) |> skia_try
        check_style(spacing.longest_line>no_lig.longest_line+3.0,"native letter spacing feature precedence") |> skia_try
        var signature=2166136261u
        for (width in array(lig.longest_line,no_lig.longest_line,kern.longest_line,no_kern.longest_line,spacing.longest_line)) {
            signature=(signature ^ uint(int(round(width*64.0))))*16777619u
        }
        print("TEXT_STYLE_SIGNATURE={signature}\n")
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=test_text_style()
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS text style: foreground/background paint, shader ownership, stroke, reset, liga, kern, feature snapshots\n")
    return 0
}
