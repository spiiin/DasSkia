options gen2
require dasskia/skia_paragraph
require dasskia/skia_scope
require math
require daslib/defer

def check_selection(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("selection_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def make_selection_text(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; settings : ParagraphOptions = ParagraphOptions()) {
    return fonts |> with_paragraph_builder(style,settings) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        return <- build_paragraph(builder)
    }
}
def test_selection() : SkiaStatus {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=24.0)) |> skia_use
        let mapping : SkiaParagraph? = make_selection_text(fonts,style,"Aé😀á\r\nאב") |> with_paragraph() |> skia_use
        var bytes <- array(0,1,3,7,8,10,11,12,14,16)
        var units <- array(0,1,2,4,5,6,7,8,9,10)
        let sizes=paragraph_text_length(mapping)
        check_selection(sizes.utf8_bytes==16 && sizes.utf16_units==10,"encoding lengths") |> skia_try
        for (i in 0 .. length(bytes)) {
            let forward=mapping |> paragraph_utf8_to_utf16(bytes[i]) |> skia_try
            let back=mapping |> paragraph_utf16_to_utf8(units[i]) |> skia_try
            check_selection(forward==units[i] && back==bytes[i],"exact scalar-boundary roundtrip") |> skia_try
        }
        for (i in 0 .. sizes.utf8_bytes+1) {
            var expected=false
            for (boundary in bytes) { if (i==boundary) { expected=true } }
            check_selection(is_ok(paragraph_utf8_to_utf16(mapping,i))==expected,"interior UTF-8 bytes rejected") |> skia_try
        }
        check_selection(is_err(paragraph_utf16_to_utf8(mapping,3)) && is_err(paragraph_utf8_to_utf16(mapping,-1)) &&
            is_err(paragraph_utf16_to_utf8(mapping,sizes.utf16_units+1)),"surrogate middle and out-of-range rejected") |> skia_try
        check_selection(is_err(paragraph_hit_test(mapping,float2(0.0))) && is_err(paragraph_word_boundary_utf16(mapping,0)) &&
            is_err(paragraph_rects_utf16(mapping,0,1)),"layout required by geometry queries") |> skia_try
        let p : SkiaParagraph? = make_selection_text(fonts,style,"office é 😀 שלום world\nsecond line") |> with_paragraph() |> skia_use
        p |> layout_paragraph(600.0) |> skia_try
        let word=p |> paragraph_word_boundary_utf8(2) |> skia_try
        check_selection(word.start_utf8==0 && word.end_utf8==6 && word.start_utf16==0 && word.end_utf16==6,"Latin word boundaries") |> skia_try
        let marked=p |> paragraph_word_boundary_utf8(8) |> skia_try
        check_selection(marked.start_utf8==7 && marked.end_utf8==10,"combining mark remains inside word") |> skia_try
        var accent <- p |> paragraph_rects_utf8(7,10) |> skia_try
        var partial <- p |> paragraph_rects_utf8(7,8) |> skia_try
        check_selection(length(accent)==1 && length(partial)==0,"selection includes complete graphemes only") |> skia_try
        var emoji <- p |> paragraph_rects_utf8(11,15) |> skia_try
        check_selection(length(emoji)==1 && emoji[0].rect.z>0.0,"supplementary scalar range") |> skia_try
        let eu=p |> paragraph_utf8_to_utf16(11) |> skia_try
        check_selection(is_err(paragraph_rects_utf16(p,eu+1,eu+2)),"no half-surrogate selection") |> skia_try
        let eb=emoji[0].rect
        let eleft=p |> paragraph_hit_test(float2(eb.x+eb.z*0.1,eb.y+eb.w*0.5)) |> skia_try
        let eright=p |> paragraph_hit_test(float2(eb.x+eb.z*0.9,eb.y+eb.w*0.5)) |> skia_try
        check_selection(eleft.position_utf8==11 && eright.position_utf8==15 && eright.position_utf16-eleft.position_utf16==2,"emoji caret skips surrogate pair") |> skia_try
        check_selection(eleft.affinity==SkiaParagraphAffinity.Downstream && eright.affinity==SkiaParagraphAffinity.Upstream,"native caret affinity") |> skia_try
        var hebrew <- p |> paragraph_rects_utf8(16,24) |> skia_try
        check_selection(length(hebrew)==1 && hebrew[0].direction==SkiaParagraphDirection.RTL,"RTL range box direction") |> skia_try
        let rb=hebrew[0].rect
        let rleft=p |> paragraph_hit_test(float2(rb.x+rb.z*0.1,rb.y+rb.w*0.5)) |> skia_try
        let rright=p |> paragraph_hit_test(float2(rb.x+rb.z*0.9,rb.y+rb.w*0.5)) |> skia_try
        check_selection(rleft.position_utf16>rright.position_utf16,"RTL caret order follows visual positions") |> skia_try
        let hw=p |> paragraph_word_boundary_utf8(18) |> skia_try
        check_selection(hw.start_utf8==16 && hw.end_utf8==24 && hw.end_utf16-hw.start_utf16==4,"RTL word and encoding conversion") |> skia_try
        let size=paragraph_text_length(p)
        var all <- p |> paragraph_rects_utf8(0,size.utf8_bytes) |> skia_try
        var utf16 <- p |> paragraph_rects_utf16(0,size.utf16_units,ParagraphRectOptions(height=SkiaParagraphRectHeight.Max,width=SkiaParagraphRectWidth.Max)) |> skia_try
        var saw_ltr,saw_rtl : bool
        var signature=2166136261u
        for (box in all) {
            if (box.direction==SkiaParagraphDirection.LTR) { saw_ltr=true } else { saw_rtl=true }
            signature=(signature ^ uint(int(round(box.rect.x*64.0))))*16777619u
            signature=(signature ^ uint(int(round(box.rect.y*64.0))))*16777619u
            signature=(signature ^ uint(int(round(box.rect.z*64.0))))*16777619u
            signature=(signature ^ uint(int(round(box.rect.w*64.0))))*16777619u
        }
        check_selection(saw_ltr && saw_rtl && length(utf16)>=length(all),"mixed bidi multiline range") |> skia_try
        print("SELECTION_SIGNATURE={signature}\n")
        var empty <- p |> paragraph_rects_utf8(0,0) |> skia_try
        var end_range <- p |> paragraph_rects_utf16(size.utf16_units,size.utf16_units) |> skia_try
        check_selection(length(empty)==0 && length(end_range)==0,"empty half-open ranges") |> skia_try
        check_selection(is_err(paragraph_rects_utf8(p,4,1)) && is_err(paragraph_rects_utf16(p,0,size.utf16_units+1)) &&
            is_err(paragraph_hit_test(p,float2(sqrt(-1.0),0.0))) && is_err(paragraph_word_boundary_utf8(p,9)),"invalid ranges, coordinates, UTF-8 boundary") |> skia_try
        let beyond=p |> paragraph_hit_test(float2(10000.0,10000.0)) |> skia_try
        let before=p |> paragraph_hit_test(float2(-100.0,-100.0)) |> skia_try
        check_selection(beyond.position_utf8==size.utf8_bytes && before.position_utf8==0,"finite out-of-paragraph positions clamp natively") |> skia_try
        let eof=p |> paragraph_word_boundary_utf16(size.utf16_units) |> skia_try
        check_selection(eof.start_utf8==size.utf8_bytes && eof.end_utf8==size.utf8_bytes,"word boundary at text end") |> skia_try
        // Script arrays are copied snapshots; reflow must not mutate saved boxes.
        let saved=all[0].rect
        p |> layout_paragraph(110.0) |> skia_try
        var narrow <- p |> paragraph_rects_utf8(0,size.utf8_bytes) |> skia_try
        check_selection(all[0].rect==saved && length(narrow)>length(all),"reflow replaces geometry without changing copied boxes") |> skia_try
        // Snapshot owns only geometry and can outlive the paragraph.
        var snapshot : SkiaParagraphRects?
        make_selection_text(fonts,style,"owned") |> with_paragraph() $(temporary : SkiaParagraph?) {
            temporary |> layout_paragraph(200.0) |> skia_try
            snapshot=Skia_ParagraphRangeRectsUtf16(temporary,0,5,SkiaParagraphRectHeight.Tight,SkiaParagraphRectWidth.Tight)
            return skia_ok()
        } |> skia_try
        {
            defer() { Skia_DeleteParagraphRects(snapshot) }
            check_selection(snapshot!=null && Skia_ParagraphRectCount(snapshot)==1,"snapshot survives paragraph destruction") |> skia_try
            var x,y,w,h : float
            var direction : SkiaParagraphDirection
            check_selection(Skia_ParagraphRectAt(snapshot,0,x,y,w,h,direction) && w>0.0 &&
                !Skia_ParagraphRectAt(snapshot,-1,x,y,w,h,direction),"snapshot data and bounds") |> skia_try
        }
        let blank : SkiaParagraph? = make_selection_text(fonts,style,"") |> with_paragraph() |> skia_use
        blank |> layout_paragraph(300.0) |> skia_try
        let bh=blank |> paragraph_hit_test(float2(10.0)) |> skia_try
        let bw=blank |> paragraph_word_boundary_utf16(0) |> skia_try
        var boxes <- blank |> paragraph_rects_utf16(0,0) |> skia_try
        check_selection(bh.position_utf16==0 && bh.position_utf8==0 && bw.end_utf16==0 && length(boxes)==0,"empty paragraph queries") |> skia_try
        let truncated : SkiaParagraph? = make_selection_text(fonts,style,"one two three four five six seven eight nine ten",ParagraphOptions(max_lines=1,ellipsis="…")) |> with_paragraph() |> skia_use
        truncated |> layout_paragraph(100.0) |> skia_try
        let tl=paragraph_text_length(truncated)
        var visible <- truncated |> paragraph_rects_utf16(0,tl.utf16_units) |> skia_try
        let th=truncated |> paragraph_hit_test(float2(1000.0,10.0)) |> skia_try
        check_selection(length(visible)>0 && th.position_utf16<=tl.utf16_units,"ellipsis keeps original indices with visible geometry") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=test_selection()
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS selection: UTF-8/16, words, hit testing, affinity, bidi, graphemes, range boxes, reflow, ownership\n")
    return 0
}
