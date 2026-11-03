options gen2
require daslib/defer
module skia_text shared public
require dasskia/skia_boost public

struct FontOptions {
    size : float = 32.0
}
struct TextOptions {
    width : float = 1000000.0
    left_to_right : bool = true
    language : string = "und"
    ligatures : bool = true
    kerning : bool = true
}
struct FontMetrics {
    ascent : float
    descent : float
    leading : float
}
struct TextMetrics {
    width : float
    height : float
    glyphs : int
    lines : int
    missing_glyphs : int
}
struct TextGlyph {
    glyph : uint
    cluster : uint
    position : float2
    bidi_level : uint
}
def public load_font(path : string; settings : FontOptions) {
    var font = Skia_LoadFont(path,settings.size)
    if (font == null) { return err(skia_error("load_font",Skia_TextError()),type<SkFont?>) }
    return <- move_ok(font,type<SkiaError>)
}
def public destroy_font(font : SkFont?) { Skia_DeleteFont(font) }
def public font_metrics(font : SkFont?) : FontMetrics {
    var result : FontMetrics
    Skia_FontMetrics(font,result.ascent,result.descent,result.leading)
    return result
}
def public shape_text(font : SkFont?; text : string; settings : TextOptions) {
    var shaped = Skia_ShapeText(font,text,uint(length(text)),settings.width,settings.left_to_right,
        settings.language,settings.ligatures,settings.kerning)
    if (shaped == null) { return err(skia_error("shape_text",Skia_TextError()),type<SkiaText?>) }
    return <- move_ok(shaped,type<SkiaError>)
}
def public destroy_text(text : SkiaText?) { Skia_DeleteText(text) }
def public text_metrics(text : SkiaText?) : TextMetrics {
    return TextMetrics(width=Skia_TextWidth(text),height=Skia_TextHeight(text),
        glyphs=Skia_TextGlyphCount(text),lines=Skia_TextLineCount(text),missing_glyphs=Skia_TextMissingGlyphs(text))
}
def public text_glyph(text : SkiaText?; index : int) {
    var glyph : TextGlyph
    var x,y : float
    if (!Skia_TextGlyph(text,index,glyph.glyph,glyph.cluster,x,y,glyph.bidi_level)) {
        return err(skia_error("text_glyph","Glyph index outside shaped text"),type<TextGlyph>)
    }
    glyph.position = float2(x,y)
    return ok(glyph,type<SkiaError>)
}
def public draw_text(canvas : SkCanvas?; text : SkiaText?; position : float2; paint : SkPaint?) {
    Skia_DrawText(canvas,text,position.x,position.y,paint)
}
def public with_font_file(path : string; settings : FontOptions; blk : block<(font : SkFont?) : $Result<auto(TT);SkiaError>>) {
    var loaded <- load_font(path,settings)
    if (is_err(loaded)) { return err(unwrap_err(loaded),type<TT>) }
    let font = move_unwrap(loaded)
    var result : $Result<TT;SkiaError>
    {
        defer() { destroy_font(font) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(font) } else { result <- blk(font) }
    }
    return <- result
}
def public with_shaped_text(font : SkFont?; text : string; settings : TextOptions;
        blk : block<(shaped : SkiaText?) : $Result<auto(TT);SkiaError>>) {
    var created <- shape_text(font,text,settings)
    if (is_err(created)) { return err(unwrap_err(created),type<TT>) }
    let shaped = move_unwrap(created)
    var result : $Result<TT;SkiaError>
    {
        defer() { destroy_text(shaped) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(shaped) } else { result <- blk(shaped) }
    }
    return <- result
}
