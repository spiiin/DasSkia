options gen2
require dasskia/skia_geometry
require dasskia/skia_effects
require dasskia/skia_scope
require math

def check_geometry(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("geometry_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def near(a,b : float2) : bool { return length(a-b)<0.002 }
def test_ops() : SkiaStatus {
    return skia_scope() {
        let a : SkPath? = with_path() |> skia_use
        let b : SkPath? = with_path() |> skia_use
        a |> add_rect(float4(10.0,10.0,30.0,30.0))
        b |> add_rect(float4(25.0,10.0,30.0,30.0))
        let united : SkPath? = path_op(a,b,SkPathOp.Union) |> with_path() |> skia_use
        let intersected : SkPath? = path_op(a,b,SkPathOp.Intersect) |> with_path() |> skia_use
        let difference : SkPath? = path_op(a,b,SkPathOp.Difference) |> with_path() |> skia_use
        let reverse : SkPath? = path_op(a,b,SkPathOp.ReverseDifference) |> with_path() |> skia_use
        let xored : SkPath? = path_op(a,b,SkPathOp.Xor) |> with_path() |> skia_use
        check_geometry(contains(united,float2(15.0,20.0)) && contains(united,float2(30.0,20.0)) && contains(united,float2(50.0,20.0)),"union") |> skia_try
        check_geometry(!contains(intersected,float2(15.0,20.0)) && contains(intersected,float2(30.0,20.0)) && !contains(intersected,float2(50.0,20.0)),"intersect") |> skia_try
        check_geometry(contains(difference,float2(15.0,20.0)) && !contains(difference,float2(30.0,20.0)) && contains(reverse,float2(50.0,20.0)) && !contains(reverse,float2(30.0,20.0)),"difference order") |> skia_try
        check_geometry(contains(xored,float2(15.0,20.0)) && !contains(xored,float2(30.0,20.0)) && contains(xored,float2(50.0,20.0)),"xor") |> skia_try
        check_geometry(path_bounds(a)==float4(10.0,10.0,30.0,30.0) && path_bounds(b)==float4(25.0,10.0,30.0,30.0),"inputs unchanged") |> skia_try
        let empty : SkPath? = path_op(a,a,SkPathOp.Difference) |> with_path() |> skia_use
        check_geometry(path_empty(empty),"empty result is success") |> skia_try
        a |> add_rect(float4(12.0,12.0,5.0,5.0))
        a |> set_fill_type(SkPathFillType.EvenOdd)
        let simplified : SkPath? = simplify_path(a) |> with_path() |> skia_use
        let winding : SkPath? = path_as_winding(a) |> with_path() |> skia_use
        check_geometry(!contains(simplified,float2(14.0,14.0)) && !contains(winding,float2(14.0,14.0)) && fill_type(winding)==SkPathFillType.Winding,"simplify and winding preserve hole") |> skia_try
        let builder : SkOpBuilder? = with_path_builder() |> skia_use
        builder |> path_builder_add(united)
        builder |> path_builder_add(b,SkPathOp.Difference)
        let built : SkPath? = resolve_path(builder) |> with_path() |> skia_use
        check_geometry(contains(built,float2(15.0,20.0)) && !contains(built,float2(30.0,20.0)),"batch operations") |> skia_try
        let reset : SkPath? = resolve_path(builder) |> with_path() |> skia_use
        check_geometry(path_empty(reset),"resolve resets builder") |> skia_try
        // The builder copies path values when adding them.
        builder |> path_builder_add(b)
        Skia_PathReset(b)
        let copied : SkPath? = resolve_path(builder) |> with_path() |> skia_use
        check_geometry(contains(copied,float2(30.0,20.0)),"builder owns geometry") |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,64))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        let c=canvas(surface)
        c |> clear(0u)
        c |> draw_path(xored,paint)
        let left=surface |> read_pixel(int2(15,20)) |> skia_try
        let middle=surface |> read_pixel(int2(30,20)) |> skia_try
        let right=surface |> read_pixel(int2(50,20)) |> skia_try
        check_geometry(left==0xffff0000u && middle==0u && right==0xffff0000u,"xor raster pixels") |> skia_try
        return skia_ok()
    }
}
def test_svg_and_stroke() : SkiaStatus {
    return skia_scope() {
        let path : SkPath? = path_from_svg("m 10 10 h 30 v 20 h -30 z M 50 50 C 55 45 65 45 70 50 Q 65 60 60 50 A 5 5 0 0 1 50 50 z") |> with_path() |> skia_use
        check_geometry(contains(path,float2(20.0,20.0)) && path_finite(path),"SVG relative, cubic, quadratic and arc commands") |> skia_try
        for (relative in fixed_array(false,true)) {
            let data=path |> path_to_svg(relative) |> skia_try
            path_from_svg(data) |> with_path() $(restored : SkPath?) {
                check_geometry(contains(restored,float2(20.0,20.0)) && length(path_bounds(restored)-path_bounds(path))<0.01,"SVG roundtrip geometry") |> skia_try
                return skia_ok()
            } |> skia_try
        }
        var invalid <- path_from_svg("M 10,10 L nope")
        check_geometry(is_err(invalid),"malformed SVG rejects prefix") |> skia_try
        let empty : SkPath? = path_from_svg("") |> with_path() |> skia_use
        check_geometry(path_empty(empty),"empty SVG path") |> skia_try
        let line : SkPath? = path_from_svg("M 10 20 L 50 20") |> with_path() |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(stroke=true,stroke_width=10.0,stroke_cap=SkStrokeCap.Square)) |> skia_use
        let fill : SkPath? = fill_path_with_paint(line,paint) |> with_path() |> skia_use
        check_geometry(path_bounds(fill)==float4(5.0,15.0,50.0,10.0) && contains(fill,float2(8.0,20.0)),"stroke to fill includes cap") |> skia_try
        var intervals <- array(8.0,8.0)
        let dash : SkPathEffect? = dash_effect(intervals) |> with_path_effect() |> skia_use
        paint |> set_stroke_cap(SkStrokeCap.Butt)
        paint |> set_path_effect(dash)
        let dashed : SkPath? = fill_path_with_paint(line,paint) |> with_path() |> skia_use
        check_geometry(contains(dashed,float2(12.0,20.0)) && !contains(dashed,float2(22.0,20.0)),"stroke conversion includes path effect") |> skia_try
        paint |> set_path_effect()
        paint |> set_stroke(true,0.0)
        var hairline <- fill_path_with_paint(line,paint)
        check_geometry(is_err(hairline),"hairline has no filled outline") |> skia_try
        line |> line_to(float2(sqrt(-1.0),0.0))
        check_geometry(!path_finite(line),"nonfinite path detection") |> skia_try
        var badop <- path_op(line,path,SkPathOp.Union)
        var badsvg <- path_to_svg(line)
        check_geometry(is_err(badop) && is_err(badsvg),"reject nonfinite operations and serialization") |> skia_try
        return skia_ok()
    }
}
def test_measure() : SkiaStatus {
    return skia_scope() {
        let path : SkPath? = path_from_svg("M 10 20 L 40 60 M 100 100 H 110 V 110 Z") |> with_path() |> skia_use
        let measure : SkPathMeasure? = create_path_measure(path) |> with_path_measure() |> skia_use
        Skia_PathReset(path)
        check_geometry(abs(measure_length(measure)-50.0)<0.001 && !measure_closed(measure),"measure copies source, current contour length") |> skia_try
        let sample=unwrap(sample_path(measure,25.0))
        check_geometry(near(sample.position,float2(25.0,40.0)) && near(sample.tangent,float2(0.6,0.8)),"position and unit tangent") |> skia_try
        check_geometry(near(unwrap(sample_path(measure,-20.0)).position,float2(10.0,20.0)) && near(unwrap(sample_path(measure,1000.0)).position,float2(40.0,60.0)),"distance clamps to contour") |> skia_try
        let m=unwrap(measure_matrix(measure,25.0))
        check_geometry(near(map_point(m,float2(0.0)),sample.position) && near(map_point(m,float2(1.0,0.0)),sample.position+sample.tangent),"position and tangent matrix") |> skia_try
        let translation=unwrap(measure_matrix(measure,25.0,true,false))
        let rotation=unwrap(measure_matrix(measure,25.0,false,true))
        check_geometry(near(map_point(translation,float2(1.0,0.0)),sample.position+float2(1.0,0.0)) && near(map_point(rotation,float2(1.0,0.0)),sample.tangent),"matrix flags") |> skia_try
        let segment : SkPath? = measure_segment(measure,10.0,30.0) |> with_path() |> skia_use
        let part : SkPathMeasure? = create_path_measure(segment) |> with_path_measure() |> skia_use
        check_geometry(abs(measure_length(part)-20.0)<0.001 && near(unwrap(sample_path(part,0.0)).position,float2(16.0,28.0)),"segment geometry") |> skia_try
        var backwards <- measure_segment(measure,30.0,10.0)
        var zero <- measure_segment(measure,10.0,10.0)
        check_geometry(is_err(backwards) && is_err(zero),"empty/reversed segment rejects") |> skia_try
        check_geometry(next_contour(measure) && measure_closed(measure) && abs(measure_length(measure)-(20.0+sqrt(200.0)))<0.002,"next closed contour") |> skia_try
        check_geometry(!next_contour(measure) && measure_length(measure)==0.0 && is_none(sample_path(measure,0.0)),"end of contours") |> skia_try
        path |> move_to(float2(0.0))
        path |> line_to(float2(30.0,40.0))
        measure |> set_measure_path(path,true) |> skia_try
        check_geometry(measure_closed(measure) && abs(measure_length(measure)-100.0)<0.001,"reset force closes contour") |> skia_try
        measure |> set_measure_path() |> skia_try
        check_geometry(measure_length(measure)==0.0 && is_none(sample_path(measure,1.0)) && is_none(measure_matrix(measure,1.0)),"clear measure and Option absence") |> skia_try
        let closed_measure : SkPathMeasure? = create_path_measure(path,PathMeasureOptions(force_closed=true,precision=2.0)) |> with_path_measure() |> skia_use
        check_geometry(measure_closed(closed_measure),"measure options") |> skia_try
        var invalid <- create_path_measure(path,PathMeasureOptions(precision=0.0))
        check_geometry(is_err(invalid) && is_none(sample_path(closed_measure,sqrt(-1.0))),"invalid precision/distance") |> skia_try
        var called=false
        let failure=path_from_svg("M bad") |> with_path() $(owned : SkPath?) { called=true; return skia_ok() }
        check_geometry(is_err(failure) && !called,"factory Err skips scope") |> skia_try
        let body_error=create_path_measure(path) |> with_path_measure() $(owned : SkPathMeasure?) { return err(skia_error("body","expected"),type<SkiaUnit>) }
        check_geometry(is_err(body_error) && unwrap_err(body_error).operation=="body","measure scope preserves Err") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    for (result in fixed_array(test_ops(),test_svg_and_stroke(),test_measure())) {
        if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    }
    print("PASS geometry: PathOps, builder, SVG data, stroke outline, contour measurement, samples, segments\n")
    return 0
}
