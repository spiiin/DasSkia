options gen2
require dasskia/skia_text
require dasskia/skia_scope
require math
require daslib/defer

def check_text(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("text_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def test_text() : SkiaStatus {
    check_text(is_err(load_font("assets/fonts/missing.ttf",FontOptions())),"missing font") |> skia_try
    check_text(is_err(load_font("assets/fonts/DejaVuSans.ttf",FontOptions(size=0.0))),"zero size") |> skia_try
    let result = skia_scope() {
        let font : SkFont? = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=32.0)) |> skia_use
        let ligature : SkiaText? = font |> with_shaped_text("ffi",TextOptions()) |> skia_use
        let plain : SkiaText? = font |> with_shaped_text("ffi",TextOptions(ligatures=false)) |> skia_use
        check_text(text_metrics(ligature).glyphs == 1 && text_metrics(plain).glyphs == 3,"ffi ligature toggle") |> skia_try
        let combining : SkiaText? = font |> with_shaped_text("á",TextOptions()) |> skia_use
        let composed : SkiaText? = font |> with_shaped_text("á",TextOptions()) |> skia_use
        let accent = combining |> text_glyph(0) |> skia_try
        let precomposed = composed |> text_glyph(0) |> skia_try
        check_text(text_metrics(combining).glyphs == 1 && accent.glyph == precomposed.glyph,"combining accent composition") |> skia_try
        let arabic : SkiaText? = font |> with_shaped_text("سلام",TextOptions(left_to_right=false,language="ar")) |> skia_use
        let first = arabic |> text_glyph(0) |> skia_try
        let last = arabic |> text_glyph(text_metrics(arabic).glyphs-1) |> skia_try
        check_text(text_metrics(arabic).glyphs == 3 && first.cluster > last.cluster && first.bidi_level % 2u == 1u,"Arabic joining and RTL clusters") |> skia_try
        let kern : SkiaText? = font |> with_shaped_text("AV",TextOptions()) |> skia_use
        let no_kern : SkiaText? = font |> with_shaped_text("AV",TextOptions(kerning=false)) |> skia_use
        check_text(text_metrics(kern).width < text_metrics(no_kern).width,"kerning toggle") |> skia_try
        let wrapped : SkiaText? = font |> with_shaped_text("one two three four five",TextOptions(width=110.0)) |> skia_use
        check_text(text_metrics(wrapped).lines >= 3 && text_metrics(wrapped).height > text_metrics(kern).height,"line wrapping") |> skia_try
        let hard : SkiaText? = font |> with_shaped_text("one\n\nПривет",TextOptions()) |> skia_use
        check_text(text_metrics(hard).lines == 3,"hard and blank lines") |> skia_try
        let hard_last = hard |> text_glyph(text_metrics(hard).glyphs-1) |> skia_try
        check_text(hard_last.cluster >= 5u,"global clusters across newlines") |> skia_try
        let empty : SkiaText? = font |> with_shaped_text("",TextOptions()) |> skia_use
        check_text(text_metrics(empty).glyphs == 0 && text_metrics(empty).lines == 0,"empty text") |> skia_try
        check_text(is_err(shape_text(font,"test",TextOptions(width=0.0))),"invalid wrap width") |> skia_try
        check_text(is_err(text_glyph(ligature,-1)) && is_err(text_glyph(ligature,1)),"glyph bounds") |> skia_try
        let mixed : SkiaText? = font |> with_shaped_text("office • Привет • العربية 123 • á",TextOptions(language="und")) |> skia_use
        check_text(text_metrics(mixed).missing_glyphs == 0,"bundled font coverage") |> skia_try
        var signature = 2166136261u
        var odd_level = false
        for (i in 0 .. text_metrics(mixed).glyphs) {
            let g = mixed |> text_glyph(i) |> skia_try
            signature = (signature ^ g.glyph) * 16777619u
            signature = (signature ^ g.cluster) * 16777619u
            signature = (signature ^ uint(int(round(g.position.x*64.0)))) * 16777619u
            signature = (signature ^ uint(int(round(g.position.y*64.0)))) * 16777619u
            signature = (signature ^ g.bidi_level) * 16777619u
            if (g.bidi_level % 2u == 1u) { odd_level = true }
        }
        check_text(odd_level,"mixed text contains RTL run") |> skia_try
        print("SHAPING_SIGNATURE={signature}\n")
        return skia_ok()
    }
    if (is_err(result)) { return result }
    // A shaped blob owns its fonts. Release the original font before drawing.
    var retained : SkiaText?
    let acquired = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=32.0)) $(font : SkFont?) {
        retained = shape_text(font,"Привет • office • سلام",TextOptions()) |> skia_try
        return skia_ok()
    }
    if (is_err(acquired)) { return acquired }
    {
        defer() { destroy_text(retained) }
        return with_raster_surface(RasterSurfaceOptions(size=int2(600,90))) $(surface : SkSurface?) {
            return with_paint(PaintOptions(color=0xffffffffu)) $(paint : SkPaint?) {
                let c = canvas(surface)
                c |> clear(0xff000000u)
                c |> draw_text(retained,float2(10.0,10.0),paint)
                var ink = 0
                for (y in 10 .. 65) {
                    for (x in 10 .. 500) {
                        let pixel = surface |> read_pixel(int2(x,y)) |> skia_try
                        if (pixel != 0xff000000u) { ink++ }
                    }
                }
                check_text(ink > 300,"raster text pixels after font release") |> skia_try
                return skia_ok()
            }
        }
    }
}
[export]
def main() : int {
    let result = test_text()
    if (is_err(result)) {
        let e = unwrap_err(result)
        print("FAIL {e.operation}: {e.message}\n")
        return 1
    }
    print("PASS text: ligatures, marks, Arabic, bidi, wrapping, ownership, pixels\n")
    return 0
}
