options gen2
require daslib/defer
module skia_paragraph shared public
require dasskia/skia_boost public
require daslib/option public

// Decoration bits match SkParagraph: underline=1, overline=2, line-through=4.
let public PARAGRAPH_UNDERLINE = 1u
let public PARAGRAPH_OVERLINE = 2u
let public PARAGRAPH_LINE_THROUGH = 4u
struct ParagraphTextOptions {
    size : float = 24.0
    color : uint = 0xff000000u
    weight : int = 400
    font_width : int = 5
    italic : bool = false
    letter_spacing : float = 0.0
    word_spacing : float = 0.0
    height : float = 0.0 // zero: native font height; positive: line-height multiplier
    decorations : uint = 0u
    locale : string = "und"
}
struct ParagraphOptions {
    align : SkiaParagraphAlign = SkiaParagraphAlign.Start
    direction : SkiaParagraphDirection = SkiaParagraphDirection.LTR
    max_lines : int = 0 // unlimited
    ellipsis : string = ""
    height_behavior : SkiaTextHeightBehavior = SkiaTextHeightBehavior.All
}
struct ParagraphMetrics {
    width : float
    height : float
    min_intrinsic_width : float
    max_intrinsic_width : float
    alphabetic_baseline : float
    ideographic_baseline : float
    longest_line : float
    lines : int
    unresolved_glyphs : int
    exceeded_max_lines : bool
}
struct ParagraphLineMetrics {
    ascent : float
    descent : float
    height : float
    width : float
    left : float
    baseline : float
    hard_break : bool
}

def public create_paragraph_fonts() : SkiaParagraphFonts? { return Skia_NewParagraphFonts() }
def public destroy_paragraph_fonts(fonts : SkiaParagraphFonts?) { Skia_DeleteParagraphFonts(fonts) }
def public add_paragraph_font(fonts : SkiaParagraphFonts?; path,family : string) : SkiaStatus {
    if (!Skia_ParagraphAddFont(fonts,path,family)) { return err(skia_error("add_paragraph_font",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public create_paragraph_style(families : array<string>; settings : ParagraphTextOptions = ParagraphTextOptions()) {
    var style=Skia_NewParagraphTextStyle(settings.size,settings.color,settings.weight,settings.font_width,settings.italic,
        settings.letter_spacing,settings.word_spacing,settings.height,settings.decorations)
    if (style==null) { return err(skia_error("create_paragraph_style",Skia_ParagraphError()),type<SkiaParagraphTextStyle?>) }
    if (!Skia_ParagraphStyleFamilies(style,families,settings.locale)) {
        Skia_DeleteParagraphTextStyle(style)
        return err(skia_error("create_paragraph_style",Skia_ParagraphError()),type<SkiaParagraphTextStyle?>)
    }
    return <- move_ok(style,type<SkiaError>)
}
def public destroy_paragraph_style(style : SkiaParagraphTextStyle?) { Skia_DeleteParagraphTextStyle(style) }
def public create_paragraph_builder(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; settings : ParagraphOptions = ParagraphOptions()) {
    var builder=Skia_NewParagraphBuilderLayout(fonts,style,null,settings.align,settings.direction,settings.max_lines,settings.ellipsis,settings.height_behavior)
    if (builder==null) { return err(skia_error("create_paragraph_builder",Skia_ParagraphError()),type<SkiaParagraphBuilder?>) }
    return <- move_ok(builder,type<SkiaError>)
}
def public destroy_paragraph_builder(builder : SkiaParagraphBuilder?) { Skia_DeleteParagraphBuilder(builder) }
def public push_paragraph_style(builder : SkiaParagraphBuilder?; style : SkiaParagraphTextStyle?) : SkiaStatus {
    if (!Skia_ParagraphPushStyle(builder,style)) { return err(skia_error("push_paragraph_style",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public pop_paragraph_style(builder : SkiaParagraphBuilder?) : SkiaStatus {
    if (!Skia_ParagraphPopStyle(builder)) { return err(skia_error("pop_paragraph_style",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public add_paragraph_text(builder : SkiaParagraphBuilder?; text : string) : SkiaStatus {
    if (!Skia_ParagraphAddText(builder,text,uint(length(text)))) { return err(skia_error("add_paragraph_text",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public build_paragraph(builder : SkiaParagraphBuilder?) {
    var paragraph=Skia_BuildParagraph(builder)
    if (paragraph==null) { return err(skia_error("build_paragraph",Skia_ParagraphError()),type<SkiaParagraph?>) }
    return <- move_ok(paragraph,type<SkiaError>)
}
def public destroy_paragraph(paragraph : SkiaParagraph?) { Skia_DeleteParagraph(paragraph) }
def public layout_paragraph(paragraph : SkiaParagraph?; width : float) : SkiaStatus {
    if (!Skia_LayoutParagraph(paragraph,width)) { return err(skia_error("layout_paragraph",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public paragraph_metrics(paragraph : SkiaParagraph?) {
    var m : ParagraphMetrics
    if (!Skia_ParagraphMetrics(paragraph,m.width,m.height,m.min_intrinsic_width,m.max_intrinsic_width,m.alphabetic_baseline,
        m.ideographic_baseline,m.longest_line,m.lines,m.unresolved_glyphs,m.exceeded_max_lines)) {
        return err(skia_error("paragraph_metrics",Skia_ParagraphError()),type<ParagraphMetrics>)
    }
    return ok(m,type<SkiaError>)
}
def public paragraph_line_metrics(paragraph : SkiaParagraph?; index : int) {
    var m : ParagraphLineMetrics
    if (!Skia_ParagraphLineMetrics(paragraph,index,m.ascent,m.descent,m.height,m.width,m.left,m.baseline,m.hard_break)) {
        return err(skia_error("paragraph_line_metrics",Skia_ParagraphError()),type<ParagraphLineMetrics>)
    }
    return ok(m,type<SkiaError>)
}
// Call layout_paragraph first. Position is the paragraph top left, not its baseline.
def public draw_paragraph(canvas : SkCanvas?; paragraph : SkiaParagraph?; position : float2) {
    Skia_DrawParagraph(canvas,paragraph,position.x,position.y)
}

def public with_paragraph_fonts(blk : block<(value : SkiaParagraphFonts?) : $Result<auto(ParagraphBodyResult);SkiaError>>) {
    let value=create_paragraph_fonts()
    var result : $Result<ParagraphBodyResult;SkiaError>
    {
        defer() { destroy_paragraph_fonts(value) }
        static_if (typeinfo can_copy(type<$Result<ParagraphBodyResult;SkiaError>>)) { result=blk(value) }
        else { result <- blk(value) }
    }
    return <- result
}

def public with_paragraph_style(families : array<string>; settings : ParagraphTextOptions; blk : block<(value : SkiaParagraphTextStyle?) : $Result<auto(ParagraphBodyResult);SkiaError>>) {
    var acquired <- create_paragraph_style(families,settings)
    if (is_err(acquired)) { return err(unwrap_err(acquired),type<ParagraphBodyResult>) }
    let value=move_unwrap(acquired)
    var result : $Result<ParagraphBodyResult;SkiaError>
    {
        defer() { destroy_paragraph_style(value) }
        static_if (typeinfo can_copy(type<$Result<ParagraphBodyResult;SkiaError>>)) { result=blk(value) }
        else { result <- blk(value) }
    }
    return <- result
}

def public with_paragraph_builder(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; settings : ParagraphOptions; blk : block<(value : SkiaParagraphBuilder?) : $Result<auto(ParagraphBodyResult);SkiaError>>) {
    var acquired <- create_paragraph_builder(fonts,style,settings)
    if (is_err(acquired)) { return err(unwrap_err(acquired),type<ParagraphBodyResult>) }
    let value=move_unwrap(acquired)
    var result : $Result<ParagraphBodyResult;SkiaError>
    {
        defer() { destroy_paragraph_builder(value) }
        static_if (typeinfo can_copy(type<$Result<ParagraphBodyResult;SkiaError>>)) { result=blk(value) }
        else { result <- blk(value) }
    }
    return <- result
}

def public with_paragraph(var created : $Result<SkiaParagraph?;SkiaError>; blk : block<(value : SkiaParagraph?) : $Result<auto(ParagraphBodyResult);SkiaError>>) {
    var acquired <- created
    if (is_err(acquired)) { return err(unwrap_err(acquired),type<ParagraphBodyResult>) }
    let value=move_unwrap(acquired)
    var result : $Result<ParagraphBodyResult;SkiaError>
    {
        defer() { destroy_paragraph(value) }
        static_if (typeinfo can_copy(type<$Result<ParagraphBodyResult;SkiaError>>)) { result=blk(value) }
        else { result <- blk(value) }
    }
    return <- result
}

// All indices are offsets between Unicode scalars, not grapheme/caret indices.
struct ParagraphTextLength {
    utf8_bytes : int
    utf16_units : int
}
struct ParagraphHit {
    position_utf8 : int
    position_utf16 : int
    affinity : SkiaParagraphAffinity
}
struct ParagraphTextRange {
    start_utf8 : int
    end_utf8 : int
    start_utf16 : int
    end_utf16 : int
}
struct ParagraphRectOptions {
    height : SkiaParagraphRectHeight = SkiaParagraphRectHeight.Tight
    width : SkiaParagraphRectWidth = SkiaParagraphRectWidth.Tight
}
struct ParagraphTextBox {
    rect : float4 // paragraph-local XYWH
    direction : SkiaParagraphDirection
}
def public paragraph_text_length(paragraph : SkiaParagraph?) : ParagraphTextLength {
    var result : ParagraphTextLength
    Skia_ParagraphTextLength(paragraph,result.utf8_bytes,result.utf16_units)
    return result
}
def public paragraph_utf8_to_utf16(paragraph : SkiaParagraph?; byte_offset : int) {
    var units : int
    if (!Skia_ParagraphUtf8ToUtf16(paragraph,byte_offset,units)) { return err(skia_error("paragraph_utf8_to_utf16",Skia_ParagraphError()),type<int>) }
    return ok(units,type<SkiaError>)
}
def public paragraph_utf16_to_utf8(paragraph : SkiaParagraph?; unit_offset : int) {
    var byte : int
    if (!Skia_ParagraphUtf16ToUtf8(paragraph,unit_offset,byte)) { return err(skia_error("paragraph_utf16_to_utf8",Skia_ParagraphError()),type<int>) }
    return ok(byte,type<SkiaError>)
}
def public paragraph_hit_test(paragraph : SkiaParagraph?; position : float2) {
    var hit : ParagraphHit
    if (!Skia_ParagraphHitTest(paragraph,position.x,position.y,hit.position_utf16,hit.position_utf8,hit.affinity)) {
        return err(skia_error("paragraph_hit_test",Skia_ParagraphError()),type<ParagraphHit>)
    }
    return ok(hit,type<SkiaError>)
}
def public paragraph_word_boundary_utf16(paragraph : SkiaParagraph?; unit_offset : int) {
    var span : ParagraphTextRange
    if (!Skia_ParagraphWordBoundaryUtf16(paragraph,unit_offset,span.start_utf16,span.end_utf16)) {
        return err(skia_error("paragraph_word_boundary_utf16",Skia_ParagraphError()),type<ParagraphTextRange>)
    }
    if (!Skia_ParagraphUtf16ToUtf8(paragraph,span.start_utf16,span.start_utf8) ||
        !Skia_ParagraphUtf16ToUtf8(paragraph,span.end_utf16,span.end_utf8)) {
        return err(skia_error("paragraph_word_boundary_utf16",Skia_ParagraphError()),type<ParagraphTextRange>)
    }
    return ok(span,type<SkiaError>)
}
def public paragraph_word_boundary_utf8(paragraph : SkiaParagraph?; byte_offset : int) {
    var converted <- paragraph_utf8_to_utf16(paragraph,byte_offset)
    if (is_err(converted)) { return err(unwrap_err(converted),type<ParagraphTextRange>) }
    return <- paragraph_word_boundary_utf16(paragraph,unwrap(converted))
}
def public paragraph_rects_utf16(paragraph : SkiaParagraph?; start,end : int; settings : ParagraphRectOptions = ParagraphRectOptions()) {
    let snapshot=Skia_ParagraphRangeRectsUtf16(paragraph,start,end,settings.height,settings.width)
    if (snapshot==null) { return err(skia_error("paragraph_rects_utf16",Skia_ParagraphError()),type<array<ParagraphTextBox>>) }
    var result : array<ParagraphTextBox>
    {
        defer() { Skia_DeleteParagraphRects(snapshot) }
        for (i in 0 .. Skia_ParagraphRectCount(snapshot)) {
            var box : ParagraphTextBox
            var x,y,w,h : float
            if (!Skia_ParagraphRectAt(snapshot,i,x,y,w,h,box.direction)) {
                return err(skia_error("paragraph_rects_utf16",Skia_ParagraphError()),type<array<ParagraphTextBox>>)
            }
            box.rect=float4(x,y,w,h)
            push(result,box)
        }
    }
    return <- move_ok(result,type<SkiaError>)
}
def public paragraph_rects_utf8(paragraph : SkiaParagraph?; start,end : int; settings : ParagraphRectOptions = ParagraphRectOptions()) {
    var first <- paragraph_utf8_to_utf16(paragraph,start)
    if (is_err(first)) { return err(unwrap_err(first),type<array<ParagraphTextBox>>) }
    var last <- paragraph_utf8_to_utf16(paragraph,end)
    if (is_err(last)) { return err(unwrap_err(last),type<array<ParagraphTextBox>>) }
    return <- paragraph_rects_utf16(paragraph,unwrap(first),unwrap(last),settings)
}

struct ParagraphGraphemeBoundary {
    is_boundary : bool
    previous_utf16 : int
    next_utf16 : int
    previous_utf8 : int
    next_utf8 : int
}
struct ParagraphGraphemeInfo {
    text : ParagraphTextRange
    rect : float4
    direction : SkiaParagraphDirection
    is_ellipsis : bool
}
struct ParagraphCaret {
    position_utf16 : int
    position_utf8 : int
    affinity : SkiaParagraphAffinity
    // Zero-width XYWH. Choose visible stroke width when drawing.
    rect : float4
    direction : SkiaParagraphDirection
}
def public paragraph_grapheme_boundary_utf16(paragraph : SkiaParagraph?; position : int) {
    var g : ParagraphGraphemeBoundary
    if (!Skia_ParagraphGraphemeBoundaryUtf16(paragraph,position,g.is_boundary,g.previous_utf16,g.next_utf16) ||
        !Skia_ParagraphUtf16ToUtf8(paragraph,g.previous_utf16,g.previous_utf8) ||
        !Skia_ParagraphUtf16ToUtf8(paragraph,g.next_utf16,g.next_utf8)) {
        return err(skia_error("paragraph_grapheme_boundary_utf16",Skia_ParagraphError()),type<ParagraphGraphemeBoundary>)
    }
    return ok(g,type<SkiaError>)
}
def public paragraph_grapheme_boundary_utf8(paragraph : SkiaParagraph?; position : int) {
    var converted <- paragraph_utf8_to_utf16(paragraph,position)
    if (is_err(converted)) { return err(unwrap_err(converted),type<ParagraphGraphemeBoundary>) }
    return <- paragraph_grapheme_boundary_utf16(paragraph,unwrap(converted))
}
def public paragraph_grapheme_info_utf16(paragraph : SkiaParagraph?; position : int) {
    var g : ParagraphGraphemeInfo
    var found : bool
    var x,y,w,h : float
    if (!Skia_ParagraphGraphemeInfoUtf16(paragraph,position,found,g.text.start_utf16,g.text.end_utf16,x,y,w,h,g.direction,g.is_ellipsis)) {
        return err(skia_error("paragraph_grapheme_info_utf16",Skia_ParagraphError()),type<$Option<ParagraphGraphemeInfo>>)
    }
    if (!found) { return ok(none(type<ParagraphGraphemeInfo>),type<SkiaError>) }
    if (!Skia_ParagraphUtf16ToUtf8(paragraph,g.text.start_utf16,g.text.start_utf8) || !Skia_ParagraphUtf16ToUtf8(paragraph,g.text.end_utf16,g.text.end_utf8)) {
        return err(skia_error("paragraph_grapheme_info_utf16",Skia_ParagraphError()),type<$Option<ParagraphGraphemeInfo>>)
    }
    g.rect=float4(x,y,w,h)
    return ok(some(g),type<SkiaError>)
}
def public paragraph_grapheme_info_utf8(paragraph : SkiaParagraph?; position : int) {
    var converted <- paragraph_utf8_to_utf16(paragraph,position)
    if (is_err(converted)) { return err(unwrap_err(converted),type<$Option<ParagraphGraphemeInfo>>) }
    return <- paragraph_grapheme_info_utf16(paragraph,unwrap(converted))
}
def public paragraph_caret_utf16(paragraph : SkiaParagraph?; position : int; affinity : SkiaParagraphAffinity = SkiaParagraphAffinity.Downstream) {
    var c : ParagraphCaret
    var found : bool
    var x,y,h : float
    if (!Skia_ParagraphCaretUtf16(paragraph,position,affinity,found,x,y,h,c.direction)) {
        return err(skia_error("paragraph_caret_utf16",Skia_ParagraphError()),type<$Option<ParagraphCaret>>)
    }
    if (!found) { return ok(none(type<ParagraphCaret>),type<SkiaError>) }
    c.position_utf16=position; c.affinity=affinity; c.rect=float4(x,y,0.0,h)
    if (!Skia_ParagraphUtf16ToUtf8(paragraph,position,c.position_utf8)) {
        return err(skia_error("paragraph_caret_utf16",Skia_ParagraphError()),type<$Option<ParagraphCaret>>)
    }
    return ok(some(c),type<SkiaError>)
}
def public paragraph_caret_utf8(paragraph : SkiaParagraph?; position : int; affinity : SkiaParagraphAffinity = SkiaParagraphAffinity.Downstream) {
    var converted <- paragraph_utf8_to_utf16(paragraph,position)
    if (is_err(converted)) { return err(unwrap_err(converted),type<$Option<ParagraphCaret>>) }
    return <- paragraph_caret_utf16(paragraph,unwrap(converted),affinity)
}

struct ParagraphStrutOptions {
    enabled : bool = true
    height : float = 1.0
    leading : float = -1.0
    force_height : bool = false
    height_override : bool = false
    half_leading : bool = false
}
struct ParagraphPlaceholderOptions {
    size : float2 = float2(24.0,24.0)
    alignment : SkiaPlaceholderAlignment = SkiaPlaceholderAlignment.Baseline
    baseline : SkiaTextBaseline = SkiaTextBaseline.Alphabetic
    baseline_offset : float = 0.0
}
def public create_paragraph_strut(font_style : SkiaParagraphTextStyle?; settings : ParagraphStrutOptions = ParagraphStrutOptions()) {
    var strut=Skia_NewParagraphStrut(font_style,settings.enabled,settings.height,settings.leading,settings.force_height,settings.height_override,settings.half_leading)
    if (strut==null) { return err(skia_error("create_paragraph_strut",Skia_ParagraphError()),type<SkiaParagraphStrut?>) }
    return <- move_ok(strut,type<SkiaError>)
}
def public destroy_paragraph_strut(strut : SkiaParagraphStrut?) { Skia_DeleteParagraphStrut(strut) }
def public create_paragraph_builder(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; strut : SkiaParagraphStrut?; settings : ParagraphOptions = ParagraphOptions()) {
    var builder=Skia_NewParagraphBuilderLayout(fonts,style,strut,settings.align,settings.direction,settings.max_lines,settings.ellipsis,settings.height_behavior)
    if (builder==null) { return err(skia_error("create_paragraph_builder",Skia_ParagraphError()),type<SkiaParagraphBuilder?>) }
    return <- move_ok(builder,type<SkiaError>)
}
def public add_paragraph_placeholder(builder : SkiaParagraphBuilder?; settings : ParagraphPlaceholderOptions = ParagraphPlaceholderOptions()) {
    var span : ParagraphTextRange
    if (!Skia_ParagraphAddPlaceholder(builder,settings.size.x,settings.size.y,settings.alignment,settings.baseline,settings.baseline_offset,span.start_utf8,span.start_utf16)) {
        return err(skia_error("add_paragraph_placeholder",Skia_ParagraphError()),type<ParagraphTextRange>)
    }
    span.end_utf8=span.start_utf8+3; span.end_utf16=span.start_utf16+1
    return ok(span,type<SkiaError>)
}
def public paragraph_placeholder_rects(paragraph : SkiaParagraph?) {
    let snapshot=Skia_ParagraphPlaceholderRects(paragraph)
    if (snapshot==null) { return err(skia_error("paragraph_placeholder_rects",Skia_ParagraphError()),type<array<ParagraphTextBox>>) }
    var result : array<ParagraphTextBox>
    {
        defer() { Skia_DeleteParagraphRects(snapshot) }
        for (i in 0 .. Skia_ParagraphRectCount(snapshot)) {
            var box : ParagraphTextBox
            var x,y,w,h : float
            if (!Skia_ParagraphRectAt(snapshot,i,x,y,w,h,box.direction)) {
                return err(skia_error("paragraph_placeholder_rects",Skia_ParagraphError()),type<array<ParagraphTextBox>>)
            }
            box.rect=float4(x,y,w,h); push(result,box)
        }
    }
    return <- move_ok(result,type<SkiaError>)
}
def public with_paragraph_strut(font_style : SkiaParagraphTextStyle?; settings : ParagraphStrutOptions;
        blk : block<(value : SkiaParagraphStrut?) : $Result<auto(StrutBodyResult);SkiaError>>) {
    var acquired <- create_paragraph_strut(font_style,settings)
    if (is_err(acquired)) { return err(unwrap_err(acquired),type<StrutBodyResult>) }
    let value=move_unwrap(acquired)
    var result : $Result<StrutBodyResult;SkiaError>
    {
        defer() { destroy_paragraph_strut(value) }
        static_if (typeinfo can_copy(type<$Result<StrutBodyResult;SkiaError>>)) { result=blk(value) }
        else { result <- blk(value) }
    }
    return <- result
}
def public with_paragraph_builder(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; strut : SkiaParagraphStrut?; settings : ParagraphOptions;
        blk : block<(value : SkiaParagraphBuilder?) : $Result<auto(StrutBodyResult);SkiaError>>) {
    var acquired <- create_paragraph_builder(fonts,style,strut,settings)
    if (is_err(acquired)) { return err(unwrap_err(acquired),type<StrutBodyResult>) }
    let value=move_unwrap(acquired)
    var result : $Result<StrutBodyResult;SkiaError>
    {
        defer() { destroy_paragraph_builder(value) }
        static_if (typeinfo can_copy(type<$Result<StrutBodyResult;SkiaError>>)) { result=blk(value) }
        else { result <- blk(value) }
    }
    return <- result
}

// Native styles copy SkPaint and retain its ref-counted effects. Null clears it.
// Builder creation/push copy the complete style; later changes affect future uses.
def public set_paragraph_foreground(style : SkiaParagraphTextStyle?; paint : SkPaint? = null) { Skia_SetParagraphForeground(style,paint) }
def public set_paragraph_background(style : SkiaParagraphTextStyle?; paint : SkPaint? = null) { Skia_SetParagraphBackground(style,paint) }
def public add_paragraph_font_feature(style : SkiaParagraphTextStyle?; tag : string; value : int = 1) : SkiaStatus {
    if (!Skia_ParagraphAddFontFeature(style,tag,uint(length(tag)),value)) { return err(skia_error("add_paragraph_font_feature",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public reset_paragraph_font_features(style : SkiaParagraphTextStyle?) { Skia_ParagraphResetFontFeatures(style) }

struct FontVariation { tag : string; value : float }
struct FontVariationAxis { tag : string; minimum : float; normal : float; maximum : float; hidden : bool }
struct ParagraphDecorationOptions {
    bits : uint = 0u
    color : uint = 0xff000000u
    style : SkiaTextDecorationStyle = SkiaTextDecorationStyle.Solid
    mode : SkiaTextDecorationMode = SkiaTextDecorationMode.Through
    thickness : float = 1.0
}
struct ParagraphShadowOptions { color : uint = 0xff000000u; offset : float2; blur_sigma : float = 0.0 }
def public add_paragraph_font(fonts : SkiaParagraphFonts?; path,family : string; face_index : int) : SkiaStatus {
    if (!Skia_ParagraphAddFontFace(fonts,path,family,face_index)) { return err(skia_error("add_paragraph_font",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public font_variation_axes(font : SkFont?) {
    var count : int
    var result : array<FontVariationAxis>
    if (!Skia_FontAxisCount(font,count)) { return err(skia_error("font_variation_axes",Skia_ParagraphError()),type<array<FontVariationAxis>>) }
    for (i in 0 .. count) {
        var axis : FontVariationAxis
        var tag : uint
        if (!Skia_FontAxis(font,i,tag,axis.minimum,axis.normal,axis.maximum,axis.hidden)) { return err(skia_error("font_variation_axes",Skia_ParagraphError()),type<array<FontVariationAxis>>) }
        axis.tag=Skia_FontTagName(tag);push(result,axis)
    }
    return <- move_ok(result,type<SkiaError>)
}
def public set_paragraph_font_arguments(style : SkiaParagraphTextStyle?; axes : array<FontVariation>; face_index : int = 0) : SkiaStatus {
    var tags : array<uint>
    var values : array<float>
    for (axis in axes) {
        var tag : uint
        if (!Skia_FontTag(axis.tag,uint(length(axis.tag)),tag)) { return err(skia_error("set_paragraph_font_arguments",Skia_ParagraphError()),type<SkiaUnit>) }
        push(tags,tag);push(values,axis.value)
    }
    if (!Skia_ParagraphFontArguments(style,face_index,tags,values)) { return err(skia_error("set_paragraph_font_arguments",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public clear_paragraph_font_arguments(style : SkiaParagraphTextStyle?) { Skia_ParagraphClearFontArguments(style) }
def public set_paragraph_decoration(style : SkiaParagraphTextStyle?; settings : ParagraphDecorationOptions) : SkiaStatus {
    if (!Skia_ParagraphDecoration(style,settings.bits,settings.color,settings.style,settings.mode,settings.thickness)) { return err(skia_error("set_paragraph_decoration",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public add_paragraph_shadow(style : SkiaParagraphTextStyle?; settings : ParagraphShadowOptions) : SkiaStatus {
    if (!Skia_ParagraphAddShadow(style,settings.color,settings.offset.x,settings.offset.y,settings.blur_sigma)) { return err(skia_error("add_paragraph_shadow",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
def public reset_paragraph_shadows(style : SkiaParagraphTextStyle?) { Skia_ParagraphResetShadows(style) }
def public set_paragraph_baseline_shift(style : SkiaParagraphTextStyle?; shift : float) : SkiaStatus {
    if (!Skia_ParagraphBaselineShift(style,shift)) { return err(skia_error("set_paragraph_baseline_shift",Skia_ParagraphError()),type<SkiaUnit>) }
    return skia_ok()
}
