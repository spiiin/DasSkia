options gen2
require dasskia/skia_drawing
require dasskia/skia_sdl_gl
require dasskia/skia_try

var window : SkiaWindow?
var paint : SkPaint?
var path : SkPath?
var image : SkImage?
var frames : int
def drawing_init() : SkiaStatus {
    window = create_window(SkiaWindowOptions(title="dasSkia · Drawing and images",size=int2(900,640))) |> skia_try
    paint = create_paint(PaintOptions())
    path = Skia_NewPath()
    return with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) $(source : SkSurface?) {
        var pixels <- array(0xffff5d62u,0xff50d99au,0xff39b5f0u,0xfff4d36du)
        source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
        image = Skia_Snapshot(source)
        if (image == null) { return err(skia_error("snapshot","Cannot make sample image"),type<SkiaUnit>) }
        return skia_ok()
    }
}
def draw_gallery(c : SkCanvas?) : SkiaStatus {
    c |> clear(0xff181c28u)
    paint |> reset_paint()
    paint |> set_antialias(true)
    paint |> set_color(0xff39b5f0u)
    c |> draw_round_rect(float4(40.0,40.0,240.0,140.0),float2(28.0,28.0),paint)
    paint |> set_color(0xffffb55du)
    c |> draw_oval(float4(340.0,40.0,180.0,140.0),paint)
    paint |> set_color(0xff50d99au)
    c |> draw_arc(float4(600.0,40.0,160.0,140.0),-90.0,270.0,true,paint)
    // Group opacity applies to the layer once, including the overlap.
    paint |> set_alpha(0.65)
    c |> with_layer(paint) $(layer : SkCanvas?) {
        paint |> set_color(0xff39b5f0u)
        layer |> draw_circle(float2(110.0,280.0),55.0,paint)
        layer |> draw_circle(float2(175.0,280.0),55.0,paint)
        return skia_ok()
    } |> skia_try
    // Curves and a round stroke.
    Skia_PathReset(path)
    path |> move_to(float2(320.0,320.0))
    path |> quad_to(float2(370.0,180.0),float2(420.0,280.0))
    path |> conic_to(float2(470.0,370.0),float2(530.0,240.0),0.7)
    paint |> set_color(0xfff4d36du)
    paint |> set_stroke(true,9.0)
    paint |> set_stroke_cap(SkStrokeCap.Round)
    paint |> set_stroke_join(SkStrokeJoin.Round)
    c |> draw_path(path,paint)
    // Difference clipping cuts a hole from a painted rectangle.
    paint |> set_style(SkPaintStyle.Fill)
    Skia_PathReset(path)
    path |> add_oval(float4(665.0,240.0,70.0,70.0))
    c |> with_saved() $(saved : SkCanvas?) {
        saved |> clip_path(path,SkClipOp.Difference,true)
        paint |> set_color(0xffc990f0u)
        saved |> draw_round_rect(float4(600.0,220.0,200.0,110.0),float2(18.0,18.0),paint)
        return skia_ok()
    } |> skia_try
    // Even-odd filling makes a ring regardless of contour directions.
    Skia_PathReset(path)
    path |> add_oval(float4(40.0,400.0,160.0,160.0))
    path |> add_oval(float4(80.0,440.0,80.0,80.0))
    path |> set_fill_type(SkPathFillType.EvenOdd)
    paint |> set_color(0xffff5d62u)
    c |> draw_path(path,paint)
    // The same image with nearest, linear and transformed cubic sampling.
    c |> draw_image_to(image,float4(280.0,410.0,130.0,130.0))
    c |> draw_image_to(image,float4(440.0,410.0,130.0,130.0),SamplingOptions(filter=SkFilterMode.Linear))
    c |> with_saved() $(saved : SkCanvas?) {
        saved |> concat(multiply(matrix_translation(float2(725.0,475.0)),matrix_rotation(15.0)))
        saved |> draw_image_to(image,float4(-65.0,-65.0,130.0,130.0),SamplingOptions(cubic=true,b=0.0,c=0.5))
        return skia_ok()
    } |> skia_try
    return skia_ok()
}
def drawing_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("{e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return drawing_report(drawing_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result = window |> with_frame() $(c : SkCanvas?) { return draw_gallery(c) }
    frames++
    if (frames == 3) { print("PASS drawing frame 3\n") }
    return drawing_report(result)
}
[export]
def app_quit() {
    Skia_ImageUnref(image); image = null
    Skia_DeletePath(path); path = null
    Skia_DeletePaint(paint); paint = null
    destroy_window(window); window = null
}
