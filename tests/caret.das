options gen2
require dasskia/skia_paragraph
require dasskia/skia_scope
require math

def check_caret(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("caret_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def caret_text(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string) {
    return fonts |> with_paragraph_builder(style,ParagraphOptions()) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        return <- build_paragraph(builder)
    }
}
def test_caret() : SkiaStatus {
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=28.0)) |> skia_use
        let complex : SkiaParagraph? = caret_text(fonts,style,"á👩‍👩‍👧‍👦🇺🇳\r\nZ") |> with_paragraph() |> skia_use
        var boundaries <- array(0,2,13,17,19,20)
        var at=0
        for (i in 0 .. length(boundaries)) {
            let b=complex |> paragraph_grapheme_boundary_utf16(at) |> skia_try
            check_caret(b.is_boundary && at==boundaries[i],"ICU groups marks, ZWJ family, regional indicators, CRLF") |> skia_try
            if (i+1<length(boundaries)) { check_caret(b.next_utf16==boundaries[i+1],"next logical boundary") |> skia_try }
            at=b.next_utf16
        }
        for (i in 0 .. length(boundaries)) {
            let offset=boundaries[length(boundaries)-1-i]
            let b=complex |> paragraph_grapheme_boundary_utf16(offset) |> skia_try
            if (i+1<length(boundaries)) { check_caret(b.previous_utf16==boundaries[length(boundaries)-2-i],"previous logical boundary") |> skia_try }
        }
        let inside=complex |> paragraph_grapheme_boundary_utf16(1) |> skia_try
        check_caret(!inside.is_boundary && inside.previous_utf16==0 && inside.next_utf16==2,"scalar inside grapheme") |> skia_try
        check_caret(is_err(paragraph_grapheme_boundary_utf16(complex,3)) && is_err(paragraph_grapheme_boundary_utf8(complex,2)),"invalid surrogate/byte interior") |> skia_try
        let p : SkiaParagraph? = caret_text(fonts,style,"Aé😀á אב\nZ") |> with_paragraph() |> skia_use
        check_caret(is_err(paragraph_grapheme_info_utf16(p,0)) && is_err(paragraph_caret_utf16(p,0)),"layout required") |> skia_try
        p |> layout_paragraph(500.0) |> skia_try
        let info=p |> paragraph_grapheme_info_utf8(length("Aé😀a")) |> skia_try
        check_caret(is_some(info),"combining grapheme geometry exists") |> skia_try
        let g=unwrap(info)
        check_caret(g.text.start_utf8==length("Aé😀") && g.text.end_utf8==length("Aé😀á") && g.rect.z>0.0,"native complete grapheme range") |> skia_try
        check_caret(is_err(paragraph_caret_utf8(p,length("Aé😀a"))),"caret rejects grapheme interior") |> skia_try
        let leading=p |> paragraph_caret_utf8(g.text.start_utf8) |> skia_try
        let trailing=p |> paragraph_caret_utf8(g.text.end_utf8,SkiaParagraphAffinity.Upstream) |> skia_try
        check_caret(is_some(leading) && is_some(trailing),"both cluster edges") |> skia_try
        let l=unwrap(leading); let t=unwrap(trailing)
        check_caret(abs(l.rect.x-g.rect.x)<0.01 && abs(t.rect.x-g.rect.x-g.rect.z)<0.01 && l.rect.z==0.0 && l.rect.w>0.0,"LTR caret edges and zero width") |> skia_try
        let rtl_start=length("Aé😀á ")
        let rtl_end=length("Aé😀á אב")
        let rinfo=p |> paragraph_grapheme_info_utf8(rtl_start) |> skia_try
        let rg=unwrap(rinfo)
        let rc=p |> paragraph_caret_utf8(rtl_start) |> skia_try
        check_caret(unwrap(rc).direction==SkiaParagraphDirection.RTL && abs(unwrap(rc).rect.x-rg.rect.x-rg.rect.z)<0.01,"RTL leading edge is right edge") |> skia_try
        let newline=p |> paragraph_grapheme_info_utf8(rtl_end) |> skia_try
        check_caret(is_some(newline) && unwrap(newline).rect.z==0.0,"native zero-width newline bounds") |> skia_try
        let newline_caret=p |> paragraph_caret_utf8(rtl_end) |> skia_try
        check_caret(is_none(newline_caret),"zero-width cluster does not manufacture a caret") |> skia_try
        let len=paragraph_text_length(p)
        let end_down=p |> paragraph_caret_utf16(len.utf16_units) |> skia_try
        let start_up=p |> paragraph_caret_utf16(0,SkiaParagraphAffinity.Upstream) |> skia_try
        let end_up=p |> paragraph_caret_utf16(len.utf16_units,SkiaParagraphAffinity.Upstream) |> skia_try
        check_caret(is_none(end_down) && is_none(start_up) && is_some(end_up),"affinity endpoints have no invented adjacent cluster") |> skia_try
        let blank : SkiaParagraph? = caret_text(fonts,style,"") |> with_paragraph() |> skia_use
        blank |> layout_paragraph(500.0) |> skia_try
        let empty=blank |> paragraph_caret_utf16(0) |> skia_try
        let empty_b=blank |> paragraph_grapheme_boundary_utf16(0) |> skia_try
        check_caret(is_none(empty) && empty_b.is_boundary && empty_b.previous_utf16==0 && empty_b.next_utf16==0,"empty paragraph") |> skia_try
        let wrap : SkiaParagraph? = caret_text(fonts,style,"one two three four five six") |> with_paragraph() |> skia_use
        wrap |> layout_paragraph(120.0) |> skia_try
        var split=false
        var signature=2166136261u
        for (i in 1 .. paragraph_text_length(wrap).utf16_units) {
            let up=wrap |> paragraph_caret_utf16(i,SkiaParagraphAffinity.Upstream) |> skia_try
            let down=wrap |> paragraph_caret_utf16(i) |> skia_try
            if (is_some(up) && is_some(down)) {
                let u=unwrap(up); let d=unwrap(down)
                if (abs(u.rect.y-d.rect.y)>1.0) { split=true }
                signature=(signature ^ uint(int(round(u.rect.x*64.0))))*16777619u
                signature=(signature ^ uint(int(round(d.rect.y*64.0))))*16777619u
            }
        }
        check_caret(split,"affinity selects opposite sides of a soft wrap") |> skia_try
        let saved=l.rect
        p |> layout_paragraph(100.0) |> skia_try
        check_caret(l.rect==saved,"geometry is copied") |> skia_try
        print("CARET_SIGNATURE={signature}\n")
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=test_caret()
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS caret: ICU graphemes, navigation, geometry, affinity, RTL, wraps, endpoints\n")
    return 0
}
