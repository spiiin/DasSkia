options gen2
require dasskia/skia_paragraph
require dasskia/skia_scope
require math

def check_inline(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("inline_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def strut_text(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; strut : SkiaParagraphStrut?; text : string) {
    return fonts |> with_paragraph_builder(style,strut,ParagraphOptions()) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        return <- build_paragraph(builder)
    }
}
def test_inline() : SkiaStatus {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let small : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=14.0,color=0xffffffffu)) |> skia_use
        let strut_font : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=32.0)) |> skia_use
        let big : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=64.0)) |> skia_use
        check_inline(is_err(create_paragraph_strut(small,ParagraphStrutOptions(height=0.0))) &&
            is_err(create_paragraph_strut(small,ParagraphStrutOptions(leading=sqrt(-1.0)))),"invalid strut parameters") |> skia_try
        let strut : SkiaParagraphStrut? = strut_font |> with_paragraph_strut(ParagraphStrutOptions(height=2.0,height_override=true,leading=0.25,force_height=true)) |> skia_use
        let half : SkiaParagraphStrut? = strut_font |> with_paragraph_strut(ParagraphStrutOptions(height=2.0,height_override=true,leading=0.25,force_height=true,half_leading=true)) |> skia_use
        let disabled : SkiaParagraphStrut? = strut_font |> with_paragraph_strut(ParagraphStrutOptions(enabled=false)) |> skia_use
        let minimum : SkiaParagraphStrut? = strut_font |> with_paragraph_strut(ParagraphStrutOptions()) |> skia_use
        let fixed : SkiaParagraphStrut? = strut_font |> with_paragraph_strut(ParagraphStrutOptions(height_override=true,force_height=true)) |> skia_use
        let normal : SkiaParagraph? = strut_text(fonts,small,null,"first\nsecond") |> with_paragraph() |> skia_use
        let spaced : SkiaParagraph? = strut_text(fonts,small,strut,"first\nsecond") |> with_paragraph() |> skia_use
        let balanced : SkiaParagraph? = strut_text(fonts,small,half,"first\nsecond") |> with_paragraph() |> skia_use
        let inactive : SkiaParagraph? = strut_text(fonts,small,disabled,"first\nsecond") |> with_paragraph() |> skia_use
        let tall : SkiaParagraph? = strut_text(fonts,big,minimum,"first\nsecond") |> with_paragraph() |> skia_use
        let forced : SkiaParagraph? = strut_text(fonts,big,fixed,"first\nsecond") |> with_paragraph() |> skia_use
        normal |> layout_paragraph(500.0) |> skia_try
        spaced |> layout_paragraph(500.0) |> skia_try
        balanced |> layout_paragraph(500.0) |> skia_try
        inactive |> layout_paragraph(500.0) |> skia_try
        tall |> layout_paragraph(500.0) |> skia_try
        forced |> layout_paragraph(500.0) |> skia_try
        let nm=paragraph_metrics(normal) |> skia_try
        let sm=paragraph_metrics(spaced) |> skia_try
        let hm=paragraph_metrics(balanced) |> skia_try
        let im=paragraph_metrics(inactive) |> skia_try
        let tm=paragraph_metrics(tall) |> skia_try
        let fm=paragraph_metrics(forced) |> skia_try
        check_inline(sm.height>nm.height*3.0 && abs(im.height-nm.height)<0.01,"strut spacing and disabled style") |> skia_try
        check_inline(abs(hm.height-sm.height)<0.1 && abs(hm.alphabetic_baseline-sm.alphabetic_baseline)>0.1,"half leading preserves height and redistributes ascent") |> skia_try
        check_inline(fm.height<tm.height && fm.height>=63.9 && fm.height<=64.1,"force height can be smaller than text ink") |> skia_try
        let line0=spaced |> paragraph_line_metrics(0) |> skia_try
        let line1=spaced |> paragraph_line_metrics(1) |> skia_try
        check_inline(abs(line1.baseline-line0.baseline-72.0)<0.1,"height multiplier and font-relative leading") |> skia_try
        var strut_boxes <- spaced |> paragraph_rects_utf16(0,5,ParagraphRectOptions(height=SkiaParagraphRectHeight.Strut)) |> skia_try
        check_inline(length(strut_boxes)==1 && strut_boxes[0].rect.w>30.0,"strut range rectangles") |> skia_try
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(small,ParagraphOptions()) |> skia_use
        check_inline(is_err(add_paragraph_placeholder(builder,ParagraphPlaceholderOptions(size=float2(-1.0,20.0)))) &&
            is_err(add_paragraph_placeholder(builder,ParagraphPlaceholderOptions(baseline_offset=sqrt(-1.0)))),"invalid placeholder leaves builder usable") |> skia_try
        builder |> add_paragraph_text("😀 A") |> skia_try
        let marker=builder |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(40.0,30.0),baseline_offset=22.0)) |> skia_try
        builder |> add_paragraph_text("é") |> skia_try
        check_inline(marker.start_utf8==6 && marker.end_utf8==9 && marker.start_utf16==4 && marker.end_utf16==5,"placeholder U+FFFC index range") |> skia_try
        let p : SkiaParagraph? = build_paragraph(builder) |> with_paragraph() |> skia_use
        check_inline(is_err(add_paragraph_placeholder(builder)) && is_err(paragraph_placeholder_rects(p)),"consumed builder and pre-layout validation") |> skia_try
        let len=paragraph_text_length(p)
        check_inline(len.utf8_bytes==11 && len.utf16_units==6 && is_err(paragraph_utf8_to_utf16(p,7)),"marker is 3 bytes / 1 UTF-16 unit") |> skia_try
        let after=p |> paragraph_utf8_to_utf16(marker.end_utf8) |> skia_try
        let step=p |> paragraph_grapheme_boundary_utf16(marker.start_utf16) |> skia_try
        check_inline(after==marker.end_utf16 && step.is_boundary && step.next_utf16==marker.end_utf16,"placeholder participates in conversion and ICU boundaries") |> skia_try
        p |> layout_paragraph(500.0) |> skia_try
        var boxes <- p |> paragraph_placeholder_rects() |> skia_try
        check_inline(length(boxes)==1 && abs(boxes[0].rect.z-40.0)<0.01 && abs(boxes[0].rect.w-30.0)<0.01,"placeholder dimensions") |> skia_try
        let rect=boxes[0].rect
        let metrics=p |> paragraph_line_metrics(0) |> skia_try
        check_inline(abs(rect.y+22.0-metrics.baseline)<0.1,"alphabetic baseline offset") |> skia_try
        var selected <- p |> paragraph_rects_utf16(marker.start_utf16,marker.end_utf16) |> skia_try
        check_inline(length(selected)==1 && abs(selected[0].rect.z-40.0)<0.01,"marker range selection") |> skia_try
        let hit=p |> paragraph_hit_test(float2(rect.x+rect.z*0.25,rect.y+rect.w*0.5)) |> skia_try
        check_inline(hit.position_utf16>=marker.start_utf16 && hit.position_utf16<=marker.end_utf16,"placeholder hit-test indices") |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(500,120))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xff39b5f0u,antialias=false)) |> skia_use
        let c=canvas(surface)
        c |> clear(0xff181c28u)
        c |> draw_paragraph(p,float2(10.0,10.0))
        let center=int2(int(rect.x+30.0),int(rect.y+25.0))
        let blank=surface |> read_pixel(center) |> skia_try
        check_inline(blank==0xff181c28u,"SkParagraph reserves space without drawing placeholder content") |> skia_try
        c |> draw_rect(float4(rect.x+10.0,rect.y+10.0,rect.z,rect.w),paint)
        let filled=surface |> read_pixel(center) |> skia_try
        check_inline(filled==0xff39b5f0u,"caller draws content at placeholder bounds") |> skia_try
        let saved=boxes[0].rect
        p |> layout_paragraph(50.0) |> skia_try
        var narrow <- p |> paragraph_placeholder_rects() |> skia_try
        check_inline(boxes[0].rect==saved && length(narrow)==1,"placeholder snapshot survives reflow") |> skia_try
        var alignments <- array(SkiaPlaceholderAlignment.AboveBaseline,SkiaPlaceholderAlignment.BelowBaseline,SkiaPlaceholderAlignment.Top,SkiaPlaceholderAlignment.Bottom,SkiaPlaceholderAlignment.Middle)
        for (align in alignments) {
            fonts |> with_paragraph_builder(small,ParagraphOptions()) $(b : SkiaParagraphBuilder?) {
                b |> add_paragraph_text("x") |> skia_try
                b |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(20.0,25.0),alignment=align)) |> skia_try
                return build_paragraph(b) |> with_paragraph() $(q : SkiaParagraph?) {
                    q |> layout_paragraph(200.0) |> skia_try
                    var qb <- q |> paragraph_placeholder_rects() |> skia_try
                    let lm=q |> paragraph_line_metrics(0) |> skia_try
                    check_inline(length(qb)==1 && abs(qb[0].rect.w-25.0)<0.01,"all placeholder alignments") |> skia_try
                    if (align==SkiaPlaceholderAlignment.AboveBaseline) { check_inline(abs(qb[0].rect.y+25.0-lm.baseline)<0.1,"above baseline") |> skia_try }
                    if (align==SkiaPlaceholderAlignment.BelowBaseline) { check_inline(abs(qb[0].rect.y-lm.baseline)<0.1,"below baseline") |> skia_try }
                    return skia_ok()
                }
            } |> skia_try
        }
        let retained : SkiaParagraph? = strut_font |> with_paragraph_strut(ParagraphStrutOptions(height=2.0,height_override=true)) $(temporary : SkiaParagraphStrut?) {
            return <- strut_text(fonts,small,temporary,"retained strut")
        } |> with_paragraph() |> skia_use
        retained |> layout_paragraph(500.0) |> skia_try
        let retained_metrics=paragraph_metrics(retained) |> skia_try
        check_inline(retained_metrics.height>60.0,"paragraph owns copied strut after strut handle destruction") |> skia_try
        fonts |> with_paragraph_builder(small,ParagraphOptions(direction=SkiaParagraphDirection.RTL)) $(b : SkiaParagraphBuilder?) {
            b |> add_paragraph_text("אב ") |> skia_try
            let one=b |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(20.0,25.0),baseline=SkiaTextBaseline.Ideographic,baseline_offset=20.0)) |> skia_try
            b |> add_paragraph_text(" גד ") |> skia_try
            b |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(30.0,25.0),alignment=SkiaPlaceholderAlignment.Middle)) |> skia_try
            return build_paragraph(b) |> with_paragraph() $(q : SkiaParagraph?) {
                q |> layout_paragraph(300.0) |> skia_try
                var qb <- q |> paragraph_placeholder_rects() |> skia_try
                var selected_one <- q |> paragraph_rects_utf16(one.start_utf16,one.end_utf16) |> skia_try
                check_inline(length(qb)==2 && abs(qb[0].rect.z-20.0)<0.01 && abs(qb[1].rect.z-30.0)<0.01 &&
                    qb[0].direction==SkiaParagraphDirection.RTL && length(selected_one)==1,"RTL placeholders, source order, ideographic baseline and range selection") |> skia_try
                return skia_ok()
            }
        } |> skia_try
        fonts |> with_paragraph_builder(small,ParagraphOptions(max_lines=1,ellipsis="…")) $(b : SkiaParagraphBuilder?) {
            b |> add_paragraph_text("one two three four five six seven eight nine ten ") |> skia_try
            b |> add_paragraph_placeholder() |> skia_try
            return build_paragraph(b) |> with_paragraph() $(q : SkiaParagraph?) {
                q |> layout_paragraph(70.0) |> skia_try
                var qb <- q |> paragraph_placeholder_rects() |> skia_try
                check_inline(length(qb)==0,"ellipsized placeholder has no visible rectangle") |> skia_try
                return skia_ok()
            }
        } |> skia_try
        fonts |> with_paragraph_builder(small,ParagraphOptions()) $(b : SkiaParagraphBuilder?) {
            b |> add_paragraph_placeholder(ParagraphPlaceholderOptions(size=float2(0.0))) |> skia_try
            return build_paragraph(b) |> with_paragraph() $(q : SkiaParagraph?) {
                q |> layout_paragraph(300.0) |> skia_try
                let size=paragraph_text_length(q)
                var qb <- q |> paragraph_placeholder_rects() |> skia_try
                check_inline(size.utf8_bytes==3 && size.utf16_units==1,"zero-size placeholder still contributes a marker") |> skia_try
                for (box in qb) { check_inline(box.rect.z==0.0 && box.rect.w==0.0,"zero-size placeholder native geometry") |> skia_try }
                return skia_ok()
            }
        } |> skia_try
        var signature=2166136261u
        signature=(signature ^ uint(int(round(rect.x*64.0))))*16777619u
        signature=(signature ^ uint(int(round(rect.y*64.0))))*16777619u
        signature=(signature ^ uint(int(round(sm.height*64.0))))*16777619u
        signature=(signature ^ uint(int(round(hm.alphabetic_baseline*64.0))))*16777619u
        print("INLINE_SIGNATURE={signature}\n")
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=test_inline()
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS inline layout: placeholders, indices, baseline, alignment, strut, leading, force height, reflow, pixels\n")
    return 0
}
