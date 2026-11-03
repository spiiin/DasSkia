options gen2
require dasskia/skia_paragraph
require dasskia/skia_scope
require math

def check_paragraph(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("paragraph_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def simple_paragraph(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; settings : ParagraphOptions = ParagraphOptions()) {
    return fonts |> with_paragraph_builder(style,settings) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        return <- build_paragraph(builder)
    }
}
// Returns a newly owned paragraph. None of the borrowed creation resources escape.
def retained_paragraph() {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Missing","Demo")
        let base : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=24.0,color=0xffeeeeeeu)) |> skia_use
        let accent : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=32.0,color=0xffff8040u,decorations=PARAGRAPH_UNDERLINE)) |> skia_use
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(base,ParagraphOptions()) |> skia_use
        check_paragraph(is_err(pop_paragraph_style(builder)),"style stack underflow") |> skia_try
        builder |> push_paragraph_style(accent) |> skia_try
        check_paragraph(is_err(build_paragraph(builder)),"unbalanced style stack rejected without consuming builder") |> skia_try
        builder |> add_paragraph_text("Rich text: ") |> skia_try
        builder |> pop_paragraph_style() |> skia_try
        builder |> add_paragraph_text("office • Привет • العربية 123 • שלום • á. One API for desktop and web. Wrapping and reflow use ICU and HarfBuzz.") |> skia_try
        var built <- build_paragraph(builder)
        if (is_err(built)) { return <- built }
        var paragraph=move_unwrap(built)
        if (!is_err(add_paragraph_text(builder,"after build")) || !is_err(build_paragraph(builder))) {
            destroy_paragraph(paragraph)
            return err(skia_error("paragraph_test","builder must be consumed once"),type<SkiaParagraph?>)
        }
        var owned=paragraph
        return <- move_ok(owned,type<SkiaError>)
    }
}
def test_paragraph() : SkiaStatus {
    var families <- array("Demo")
    var no_families : array<string>
    check_paragraph(is_err(create_paragraph_style(families,ParagraphTextOptions(size=0.0))),"invalid font size") |> skia_try
    check_paragraph(is_err(create_paragraph_style(no_families)),"explicit families required") |> skia_try
    let result=skia_scope() {
        let paragraph : SkiaParagraph? = retained_paragraph() |> with_paragraph() |> skia_use
        check_paragraph(is_err(paragraph_metrics(paragraph)),"layout required before metrics") |> skia_try
        check_paragraph(is_err(layout_paragraph(paragraph,0.0)) && is_err(layout_paragraph(paragraph,sqrt(-1.0))),"invalid width") |> skia_try
        paragraph |> layout_paragraph(240.0) |> skia_try
        let narrow=paragraph_metrics(paragraph) |> skia_try
        check_paragraph(narrow.lines>=4 && narrow.unresolved_glyphs==0 && narrow.width==240.0,"multilingual rich text and explicit family fallback") |> skia_try
        check_paragraph(narrow.min_intrinsic_width>0.0 && narrow.max_intrinsic_width>narrow.min_intrinsic_width && narrow.alphabetic_baseline>0.0,"intrinsic and baseline metrics") |> skia_try
        check_paragraph(is_err(paragraph_line_metrics(paragraph,-1)) && is_err(paragraph_line_metrics(paragraph,narrow.lines)),"line bounds") |> skia_try
        var signature=2166136261u
        for (i in 0 .. narrow.lines) {
            let line=paragraph |> paragraph_line_metrics(i) |> skia_try
            check_paragraph(line.width>0.0 && line.ascent>0.0 && line.baseline>0.0,"line metrics") |> skia_try
            signature=(signature ^ uint(int(round(line.width*64.0))))*16777619u
            signature=(signature ^ uint(int(round(line.baseline*64.0))))*16777619u
            signature=(signature ^ uint(int(round(line.height*64.0))))*16777619u
        }
        print("PARAGRAPH_SIGNATURE={signature}\n")
        paragraph |> layout_paragraph(700.0) |> skia_try
        let wide=paragraph_metrics(paragraph) |> skia_try
        check_paragraph(wide.lines<narrow.lines && wide.height<narrow.height,"relayout with new width") |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(760,220))) |> skia_use
        let c=canvas(surface)
        c |> clear(0xff000000u)
        c |> draw_paragraph(paragraph,float2(10.0,10.0))
        var warm,light : int
        for (y in 10 .. 210) {
            for (x in 10 .. 750) {
                let color=surface |> read_pixel(int2(x,y)) |> skia_try
                let red=(color>>16)&255u; let green=(color>>8)&255u; let blue=color&255u
                if (red>180u && green>50u && red>blue+80u) { warm++ }
                if (red>180u && green>180u && blue>180u) { light++ }
            }
        }
        check_paragraph(warm>100 && light>300,"both rich text styles draw after all creation resources are released") |> skia_try
        return skia_ok()
    }
    if (is_err(result)) { return result }
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        check_paragraph(is_err(add_paragraph_font(fonts,"missing.ttf","Demo")),"missing font file") |> skia_try
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=24.0)) |> skia_use
        check_paragraph(is_err(create_paragraph_builder(fonts,style)),"empty font collection rejected") |> skia_try
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        check_paragraph(is_err(create_paragraph_builder(fonts,style,ParagraphOptions(max_lines=-1))),"negative max_lines") |> skia_try
        let limited : SkiaParagraph? = simple_paragraph(fonts,style,"one two three four five six seven eight nine ten eleven twelve thirteen fourteen",ParagraphOptions(max_lines=2,ellipsis="…")) |> with_paragraph() |> skia_use
        check_paragraph(is_err(add_paragraph_font(fonts,"assets/fonts/DejaVuSans.ttf","Late")),"font collection frozen on first builder") |> skia_try
        limited |> layout_paragraph(150.0) |> skia_try
        let lm=paragraph_metrics(limited) |> skia_try
        check_paragraph(lm.lines==2 && lm.exceeded_max_lines && lm.unresolved_glyphs==0,"max lines and Unicode ellipsis") |> skia_try
        let centered : SkiaParagraph? = simple_paragraph(fonts,style,"Center",ParagraphOptions(align=SkiaParagraphAlign.Center)) |> with_paragraph() |> skia_use
        centered |> layout_paragraph(400.0) |> skia_try
        let center_line=centered |> paragraph_line_metrics(0) |> skia_try
        check_paragraph(abs(center_line.left-(400.0-center_line.width)*0.5)<0.02,"center alignment") |> skia_try
        let rtl : SkiaParagraph? = simple_paragraph(fonts,style,"سلام",ParagraphOptions(direction=SkiaParagraphDirection.RTL)) |> with_paragraph() |> skia_use
        rtl |> layout_paragraph(400.0) |> skia_try
        let rtl_line=rtl |> paragraph_line_metrics(0) |> skia_try
        check_paragraph(rtl_line.left>300.0,"RTL start alignment") |> skia_try
        let hard : SkiaParagraph? = simple_paragraph(fonts,style,"first\n\nlast") |> with_paragraph() |> skia_use
        hard |> layout_paragraph(400.0) |> skia_try
        let hard_metrics=paragraph_metrics(hard) |> skia_try
        let hard_line=hard |> paragraph_line_metrics(0) |> skia_try
        check_paragraph(hard_metrics.lines==3 && hard_line.hard_break,"hard breaks and blank line") |> skia_try
        let missing : SkiaParagraph? = simple_paragraph(fonts,style,"unavailable: 􏿿") |> with_paragraph() |> skia_use
        missing |> layout_paragraph(400.0) |> skia_try
        let mm=paragraph_metrics(missing) |> skia_try
        check_paragraph(mm.unresolved_glyphs>0,"unavailable glyph reported without OS fallback") |> skia_try
        let empty : SkiaParagraph? = simple_paragraph(fonts,style,"") |> with_paragraph() |> skia_use
        empty |> layout_paragraph(400.0) |> skia_try
        let em=paragraph_metrics(empty) |> skia_try
        check_paragraph(em.height>0.0 && em.lines==0 && em.unresolved_glyphs == -1,"empty paragraph uses native font line height") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=test_paragraph()
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS paragraph: rich text, bidi, fonts, wrapping, ellipsis, metrics, reflow, ownership, pixels\n")
    return 0
}
