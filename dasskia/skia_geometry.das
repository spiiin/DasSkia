options gen2
require daslib/defer
module skia_geometry shared public
require dasskia/skia_drawing public

struct PathMeasureOptions {
    force_closed : bool = false
    precision : float = 1.0
}
struct PathSample {
    position : float2
    tangent : float2
}

def public path_finite(path : SkPath?) : bool { return Skia_PathIsFinite(path) }

def public path_op(a,b : SkPath?; operation : SkPathOp) {
    var created=Skia_PathOp(a,b,operation)
    if (created==null) { return err(skia_error("path_op","Non-finite input or path operation failed"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

def public simplify_path(path : SkPath?) {
    var created=Skia_PathSimplify(path)
    if (created==null) { return err(skia_error("simplify_path","Non-finite input or simplification failed"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

def public path_as_winding(path : SkPath?) {
    var created=Skia_PathAsWinding(path)
    if (created==null) { return err(skia_error("path_as_winding","Non-finite input or winding conversion failed"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

def public path_from_svg(data : string) {
    var created=Skia_PathFromSvg(data,uint(length(data)))
    if (created==null) { return err(skia_error("path_from_svg","Invalid SVG path data or non-finite coordinates"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

def public fill_path_with_paint(path : SkPath?; paint : SkPaint?; precision : float = 1.0) {
    var created=Skia_PathFillWithPaint(path,paint,precision)
    if (created==null) { return err(skia_error("fill_path_with_paint","Invalid path/precision or hairline cannot produce a filled path"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

def public measure_segment(measure : SkPathMeasure?; start,stop : float) {
    var created=Skia_PathMeasureSegment(measure,start,stop)
    if (created==null) { return err(skia_error("measure_segment","No nonempty segment at these finite distances"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

def public resolve_path(builder : SkOpBuilder?) {
    var created=Skia_PathBuilderResolve(builder)
    if (created==null) { return err(skia_error("resolve_path","Path builder resolution failed"),type<SkPath?>) }
    return <- move_ok(created,type<SkiaError>)
}

// SVG path data contains geometry only, not fill rule, transforms or Paint.
def public path_to_svg(path : SkPath?; relative : bool = false) {
    if (!path_finite(path)) { return err(skia_error("path_to_svg","Cannot serialize a non-finite path"),type<string>) }
    return ok(Skia_PathToSvg(path,relative),type<SkiaError>)
}
def public create_path_measure(path : SkPath?; settings : PathMeasureOptions = PathMeasureOptions()) {
    var measure=Skia_NewPathMeasure(path,settings.force_closed,settings.precision)
    if (measure==null) { return err(skia_error("create_path_measure","Path must be finite and precision finite/positive"),type<SkPathMeasure?>) }
    return <- move_ok(measure,type<SkiaError>)
}
def public set_measure_path(measure : SkPathMeasure?; path : SkPath? = null; force_closed : bool = false) : SkiaStatus {
    if (!Skia_PathMeasureSetPath(measure,path,force_closed)) { return err(skia_error("set_measure_path","Path must be finite"),type<SkiaUnit>) }
    return skia_ok()
}
def public measure_length(measure : SkPathMeasure?) : float { return Skia_PathMeasureLength(measure) }
def public measure_closed(measure : SkPathMeasure?) : bool { return Skia_PathMeasureIsClosed(measure) }
def public next_contour(measure : SkPathMeasure?) : bool { return Skia_PathMeasureNext(measure) }
def public sample_path(measure : SkPathMeasure?; distance : float) {
    var sample : PathSample
    if (!Skia_PathMeasurePosTan(measure,distance,sample.position,sample.tangent)) { return none(type<PathSample>) }
    return some(sample)
}
def public measure_matrix(measure : SkPathMeasure?; distance : float; position : bool = true; tangent : bool = true) {
    var m=matrix()
    if (!Skia_PathMeasureMatrix(measure,distance,position,tangent,m)) { return none(type<SkiaMatrix>) }
    return some(m)
}
def public path_builder_add(builder : SkOpBuilder?; path : SkPath?; operation : SkPathOp = SkPathOp.Union) { Skia_PathBuilderAdd(builder,path,operation) }

def public with_path_builder(blk : block<(builder : SkOpBuilder?) : $Result<auto(BuilderBodyResult);SkiaError>>) {
    let builder=Skia_NewPathBuilder()
    var result : $Result<BuilderBodyResult;SkiaError>
    {
        defer() { Skia_DeletePathBuilder(builder) }
        static_if (typeinfo can_copy(type<$Result<BuilderBodyResult;SkiaError>>)) { result=blk(builder) } else { result <- blk(builder) }
    }
    return <- result
}

// Consumes a factory Result; the callback borrows the resulting resource.
def public with_path(var created : $Result<SkPath?;SkiaError>; blk : block<(resource : SkPath?) : $Result<auto(PathBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<PathBodyResult>) }
    let resource=move_unwrap(created)
    var result : $Result<PathBodyResult;SkiaError>
    {
        defer() { Skia_DeletePath(resource) }
        static_if (typeinfo can_copy(type<$Result<PathBodyResult;SkiaError>>)) { result=blk(resource) } else { result <- blk(resource) }
    }
    return <- result
}

// Consumes a factory Result; the callback borrows the resulting resource.
def public with_path_measure(var created : $Result<SkPathMeasure?;SkiaError>; blk : block<(resource : SkPathMeasure?) : $Result<auto(PathBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<PathBodyResult>) }
    let resource=move_unwrap(created)
    var result : $Result<PathBodyResult;SkiaError>
    {
        defer() { Skia_DeletePathMeasure(resource) }
        static_if (typeinfo can_copy(type<$Result<PathBodyResult;SkiaError>>)) { result=blk(resource) } else { result <- blk(resource) }
    }
    return <- result
}
