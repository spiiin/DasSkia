options gen2
require daslib/defer
module skia_boost shared public
require dasskia/skia_result public

struct PaintOptions {
    color : uint = 0xff000000u
    antialias : bool = true
    stroke : bool = false
    stroke_width : float = 1.0
    stroke_cap : SkStrokeCap = SkStrokeCap.Butt
    stroke_join : SkStrokeJoin = SkStrokeJoin.Miter
    stroke_miter : float = 4.0
    blend_mode : SkBlendMode = SkBlendMode.SrcOver
}
struct RasterSurfaceOptions {
    size : int2 = int2(800,600)
}
def public argb8(a,r,g,b : uint) : uint {
    return ((a & 255u) << 24) | ((r & 255u) << 16) | ((g & 255u) << 8) | (b & 255u)
}
def public create_raster_surface(settings : RasterSurfaceOptions) {
    var surface = Skia_NewRaster(settings.size.x,settings.size.y)
    if (surface == null) { return err(skia_error("create_raster_surface","Invalid dimensions or raster allocation failed"),type<SkSurface?>) }
    return <- move_ok(surface,type<SkiaError>)
}
def public canvas(surface : SkSurface?) : SkCanvas? { return Skia_GetCanvas(surface) }
def public surface_size(surface : SkSurface?) : int2 { return int2(Skia_SurfaceWidth(surface),Skia_SurfaceHeight(surface)) }
def public create_paint(settings : PaintOptions) : SkPaint? {
    var paint = Skia_NewPaint()
    Skia_SetColor(paint,settings.color)
    Skia_SetAntialias(paint,settings.antialias)
    Skia_SetStroke(paint,settings.stroke,settings.stroke_width)
    Skia_SetStrokeCap(paint,settings.stroke_cap)
    Skia_SetStrokeJoin(paint,settings.stroke_join)
    Skia_SetStrokeMiter(paint,settings.stroke_miter)
    Skia_SetBlendMode(paint,settings.blend_mode)
    return paint
}
def public clear(canvas : SkCanvas?; color : uint) { Skia_Clear(canvas,color) }
def public draw_rect(canvas : SkCanvas?; rect : float4; paint : SkPaint?) {
    Skia_DrawRect(canvas,rect.x,rect.y,rect.z,rect.w,paint)
}
def public draw_circle(canvas : SkCanvas?; center : float2; radius : float; paint : SkPaint?) {
    Skia_DrawCircle(canvas,center.x,center.y,radius,paint)
}
def public draw_path(canvas : SkCanvas?; path : SkPath?; paint : SkPaint?) { Skia_DrawPath(canvas,path,paint) }
def public draw_image(canvas : SkCanvas?; image : SkImage?; position : float2) { Skia_DrawImage(canvas,image,position.x,position.y) }
def public move_to(path : SkPath?; position : float2) { Skia_PathMoveTo(path,position.x,position.y) }
def public line_to(path : SkPath?; position : float2) { Skia_PathLineTo(path,position.x,position.y) }
def public cubic_to(path : SkPath?; a,b,c : float2) { Skia_PathCubicTo(path,a.x,a.y,b.x,b.y,c.x,c.y) }
def public close_path(path : SkPath?) { Skia_PathClose(path) }
def public translate(canvas : SkCanvas?; value : float2) { Skia_Translate(canvas,value.x,value.y) }
def public scale(canvas : SkCanvas?; value : float2) { Skia_Scale(canvas,value.x,value.y) }
def public rotate(canvas : SkCanvas?; degrees : float) { Skia_Rotate(canvas,degrees) }
def public clip_rect(canvas : SkCanvas?; rect : float4) { Skia_ClipRect(canvas,rect.x,rect.y,rect.z,rect.w) }
def public read_pixel(surface : SkSurface?; position : int2) {
    var color : uint
    if (!Skia_ReadPixel(surface,position.x,position.y,color)) { return err(skia_error("read_pixel","Coordinates outside surface or readback failed"),type<uint>) }
    return ok(color,type<SkiaError>)
}
def public save_png(surface : SkSurface?; path : string) : SkiaStatus {
    if (!Skia_SavePng(surface,path)) { return err(skia_error("save_png","Raster encoding or file write failed"),type<SkiaUnit>) }
    return skia_ok()
}
def public with_saved(canvas : SkCanvas?; blk : block<(saved : SkCanvas?) : $Result<auto(TT);SkiaError>>) {
    let count = Skia_SaveCount(canvas)
    Skia_Save(canvas)
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_RestoreToCount(canvas,count) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(canvas) } else { result <- blk(canvas) }
    }
    return <- result
}

def public with_raster_surface(settings : RasterSurfaceOptions; blk : block<(value : SkSurface?) : $Result<auto(TT);SkiaError>>) {
    let value = Skia_NewRaster(settings.size.x,settings.size.y)
    if (value == null) { return err(skia_error("with_raster_surface","Invalid dimensions or raster allocation failed"),type<TT>) }
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_SurfaceUnref(value) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(value) } else { result <- blk(value) }
    }
    return <- result
}

def public with_paint(settings : PaintOptions; blk : block<(value : SkPaint?) : $Result<auto(TT);SkiaError>>) {
    let value = create_paint(settings)
    if (value == null) { return err(skia_error("with_paint","Paint allocation failed"),type<TT>) }
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_DeletePaint(value) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(value) } else { result <- blk(value) }
    }
    return <- result
}

def public with_path(blk : block<(value : SkPath?) : $Result<auto(TT);SkiaError>>) {
    let value = Skia_NewPath()
    if (value == null) { return err(skia_error("with_path","Path allocation failed"),type<TT>) }
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_DeletePath(value) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(value) } else { result <- blk(value) }
    }
    return <- result
}

def public with_image_file(path : string; blk : block<(value : SkImage?) : $Result<auto(TT);SkiaError>>) {
    let value = Skia_LoadImage(path)
    if (value == null) { return err(skia_error("with_image_file","Cannot load or decode image"),type<TT>) }
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_ImageUnref(value) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(value) } else { result <- blk(value) }
    }
    return <- result
}

def public with_snapshot(surface : SkSurface?; blk : block<(value : SkImage?) : $Result<auto(TT);SkiaError>>) {
    let value = Skia_Snapshot(surface)
    if (value == null) { return err(skia_error("with_snapshot","Cannot create snapshot"),type<TT>) }
    var result : $Result<TT;SkiaError>
    {
        defer() { Skia_ImageUnref(value) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(value) } else { result <- blk(value) }
    }
    return <- result
}
