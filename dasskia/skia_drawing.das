options gen2
require daslib/defer
require math
module skia_drawing shared public
require dasskia/skia_boost public

struct SamplingOptions {
    filter : SkFilterMode = SkFilterMode.Nearest
    mipmap : SkMipmapMode = SkMipmapMode.None
    cubic : bool = false
    b : float = 0.3333333333
    c : float = 0.3333333333
}
def public set_color(paint : SkPaint?; color : uint) { Skia_SetColor(paint,color) }
def public set_alpha(paint : SkPaint?; alpha : float) { Skia_SetAlpha(paint,alpha) }
def public set_antialias(paint : SkPaint?; enabled : bool) { Skia_SetAntialias(paint,enabled) }
def public set_stroke(paint : SkPaint?; enabled : bool; width : float = 1.0) { Skia_SetStroke(paint,enabled,width) }
def public set_stroke_cap(paint : SkPaint?; cap : SkStrokeCap) { Skia_SetStrokeCap(paint,cap) }
def public set_stroke_join(paint : SkPaint?; join : SkStrokeJoin) { Skia_SetStrokeJoin(paint,join) }
def public set_stroke_miter(paint : SkPaint?; miter : float) { Skia_SetStrokeMiter(paint,miter) }
def public set_style(paint : SkPaint?; style : SkPaintStyle) { Skia_SetPaintStyle(paint,style) }
def public set_blend_mode(paint : SkPaint?; mode : SkBlendMode) { Skia_SetBlendMode(paint,mode) }
def public reset_paint(paint : SkPaint?) { Skia_ResetPaint(paint) }
def public paint_color(paint : SkPaint?) : uint { return Skia_GetColor(paint) }
def public paint_alpha(paint : SkPaint?) : float { return Skia_GetAlpha(paint) }
def public paint_blend_mode(paint : SkPaint?) : SkBlendMode { return Skia_GetBlendMode(paint) }
def public draw_line(canvas : SkCanvas?; a,b : float2; paint : SkPaint?) { Skia_DrawLine(canvas,a,b,paint) }
def public draw_oval(canvas : SkCanvas?; rect : float4; paint : SkPaint?) { Skia_DrawOval(canvas,rect,paint) }
def public draw_round_rect(canvas : SkCanvas?; rect : float4; radius : float2; paint : SkPaint?) { Skia_DrawRoundRect(canvas,rect,radius,paint) }
def public draw_arc(canvas : SkCanvas?; oval : float4; start_degrees,sweep_degrees : float; use_center : bool; paint : SkPaint?) {
    Skia_DrawArc(canvas,oval,start_degrees,sweep_degrees,use_center,paint)
}
def public draw_paint(canvas : SkCanvas?; paint : SkPaint?) { Skia_DrawPaint(canvas,paint) }
def public clip_path(canvas : SkCanvas?; path : SkPath?; operation : SkClipOp = SkClipOp.Intersect; antialias : bool = false) { Skia_ClipPath(canvas,path,operation,antialias) }
def public clip_rect(canvas : SkCanvas?; rect : float4; operation : SkClipOp; antialias : bool = false) { Skia_ClipRectOp(canvas,rect,operation,antialias) }
def public skew(canvas : SkCanvas?; value : float2) { Skia_Skew(canvas,value.x,value.y) }
def public matrix() : SkiaMatrix { return Skia_MatrixIdentity() }
def public matrix(row0,row1,row2 : float3) : SkiaMatrix { return Skia_MatrixMake(row0,row1,row2) }
def public matrix_translation(offset : float2) : SkiaMatrix { return matrix(float3(1.0,0.0,offset.x),float3(0.0,1.0,offset.y),float3(0.0,0.0,1.0)) }
def public matrix_scale(value : float2) : SkiaMatrix { return matrix(float3(value.x,0.0,0.0),float3(0.0,value.y,0.0),float3(0.0,0.0,1.0)) }
def public matrix_rotation(degrees : float) : SkiaMatrix {
    let radians = degrees * 0.0174532925199433
    let s = sin(radians)
    let c = cos(radians)
    return matrix(float3(c,-s,0.0),float3(s,c,0.0),float3(0.0,0.0,1.0))
}
def public multiply(a,b : SkiaMatrix) : SkiaMatrix { return Skia_MatrixMultiply(a,b) }
def public map_point(m : SkiaMatrix; point : float2) : float2 { return Skia_MatrixMapPoint(m,point) }
def public inverse(m : SkiaMatrix) {
    var out = matrix()
    if (!Skia_MatrixInvert(m,out)) { return none(type<SkiaMatrix>) }
    return some(out)
}
def public concat(canvas : SkCanvas?; m : SkiaMatrix) { Skia_ConcatMatrix(canvas,m) }
def public set_matrix(canvas : SkCanvas?; m : SkiaMatrix) { Skia_SetMatrix(canvas,m) }
def public canvas_matrix(canvas : SkCanvas?) : SkiaMatrix { return Skia_GetMatrix(canvas) }
def public reset_matrix(canvas : SkCanvas?) { Skia_ResetMatrix(canvas) }
def public quad_to(path : SkPath?; control,end : float2) { Skia_PathQuadTo(path,control,end) }
def public conic_to(path : SkPath?; control,end : float2; weight : float) { Skia_PathConicTo(path,control,end,weight) }
def public arc_to(path : SkPath?; oval : float4; start_degrees,sweep_degrees : float; move : bool = false) { Skia_PathArcTo(path,oval,start_degrees,sweep_degrees,move) }
def public add_rect(path : SkPath?; rect : float4; direction : SkPathDirection = SkPathDirection.CW) { Skia_PathAddRect(path,rect,direction) }
def public add_oval(path : SkPath?; oval : float4; direction : SkPathDirection = SkPathDirection.CW) { Skia_PathAddOval(path,oval,direction) }
def public add_round_rect(path : SkPath?; rect : float4; radius : float2; direction : SkPathDirection = SkPathDirection.CW) { Skia_PathAddRoundRect(path,rect,radius,direction) }
def public set_fill_type(path : SkPath?; fill : SkPathFillType) { Skia_PathSetFillType(path,fill) }
def public fill_type(path : SkPath?) : SkPathFillType { return Skia_PathGetFillType(path) }
def public contains(path : SkPath?; point : float2) : bool { return Skia_PathContains(path,point) }
def public path_bounds(path : SkPath?) : float4 { return Skia_PathBounds(path) }
def public path_tight_bounds(path : SkPath?) : float4 { return Skia_PathTightBounds(path) }
def public transform(path : SkPath?; m : SkiaMatrix) { Skia_PathTransform(path,m) }
def public offset(path : SkPath?; value : float2) { Skia_PathOffset(path,value) }
def public add_path(path,other : SkPath?) { Skia_PathAddPath(path,other) }
def public path_empty(path : SkPath?) : bool { return Skia_PathIsEmpty(path) }
def public image_size(image : SkImage?) : int2 { return int2(Skia_ImageWidth(image),Skia_ImageHeight(image)) }
def public image_subset(image : SkImage?; rect : int4) {
    var subset = Skia_ImageSubset(image,rect.x,rect.y,rect.z,rect.w)
    if (subset == null) { return err(skia_error("image_subset","Invalid subset, texture-backed image, or subset creation failed"),type<SkImage?>) }
    return <- move_ok(subset,type<SkiaError>)
}
def public image_with_mipmaps(image : SkImage?) {
    var mipped = Skia_ImageWithMipmaps(image)
    if (mipped == null) { return err(skia_error("image_with_mipmaps","Texture-backed image or mipmap creation failed"),type<SkImage?>) }
    return <- move_ok(mipped,type<SkiaError>)
}
def public draw_image_rect(canvas : SkCanvas?; image : SkImage?; source,destination : float4;
        sampling : SamplingOptions = SamplingOptions(); paint : SkPaint? = null; strict : bool = true) {
    Skia_DrawImageRect(canvas,image,source,destination,sampling.filter,sampling.mipmap,sampling.cubic,sampling.b,sampling.c,paint,strict)
}
def public draw_image_to(canvas : SkCanvas?; image : SkImage?; destination : float4;
        sampling : SamplingOptions = SamplingOptions(); paint : SkPaint? = null) {
    let size = image_size(image)
    draw_image_rect(canvas,image,float4(0.0,0.0,float(size.x),float(size.y)),destination,sampling,paint,true)
}
def public draw_image(canvas : SkCanvas?; image : SkImage?; position : float2;
        sampling : SamplingOptions; paint : SkPaint? = null) {
    Skia_DrawImageSampled(canvas,image,position,sampling.filter,sampling.mipmap,sampling.cubic,sampling.b,sampling.c,paint)
}
def public read_pixels(surface : SkSurface?; region : int4; var pixels : array<uint>) : SkiaStatus {
    if (!Skia_ReadPixelsArgb(surface,region.x,region.y,region.z,region.w,pixels)) { return err(skia_error("read_pixels","Invalid region/capacity or readback failed"),type<SkiaUnit>) }
    return skia_ok()
}
def public write_pixels(surface : SkSurface?; region : int4; pixels : array<uint>) : SkiaStatus {
    if (!Skia_WritePixelsArgb(surface,region.x,region.y,region.z,region.w,pixels)) { return err(skia_error("write_pixels","Invalid region/capacity or pixel write failed"),type<SkiaUnit>) }
    return skia_ok()
}
def public with_layer(canvas : SkCanvas?; paint : SkPaint?; blk : block<(layer : SkCanvas?) : $Result<auto(TT);SkiaError>>) {
    let count = Skia_SaveCount(canvas)
    Skia_SaveLayer(canvas,paint)
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_RestoreToCount(canvas,count) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(canvas) } else { result <- blk(canvas) }
    }
    return <- result
}
def public with_image_subset(image : SkImage?; rect : int4; blk : block<(subset : SkImage?) : $Result<auto(TT);SkiaError>>) {
    var created <- image_subset(image,rect)
    if (is_err(created)) { return err(unwrap_err(created),type<TT>) }
    let subset = move_unwrap(created)
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_ImageUnref(subset) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(subset) } else { result <- blk(subset) }
    }
    return <- result
}
def public with_mipmapped_image(image : SkImage?; blk : block<(mipped : SkImage?) : $Result<auto(TT);SkiaError>>) {
    var created <- image_with_mipmaps(image)
    if (is_err(created)) { return err(unwrap_err(created),type<TT>) }
    let mipped = move_unwrap(created)
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_ImageUnref(mipped) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(mipped) } else { result <- blk(mipped) }
    }
    return <- result
}
def public with_paint_copy(source : SkPaint?; blk : block<(copy : SkPaint?) : $Result<auto(TT);SkiaError>>) {
    let copy = Skia_ClonePaint(source)
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_DeletePaint(copy) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(copy) } else { result <- blk(copy) }
    }
    return <- result
}
def public with_path_copy(source : SkPath?; blk : block<(copy : SkPath?) : $Result<auto(TT);SkiaError>>) {
    let copy = Skia_ClonePath(source)
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_DeletePath(copy) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(copy) } else { result <- blk(copy) }
    }
    return <- result
}
