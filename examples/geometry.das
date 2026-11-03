options gen2
require dasskia/skia_geometry
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_try
require math

var window : SkiaWindow?
var paint : SkPaint?
var ink : SkPaint?
var paths : array<SkPath?>
var labels : array<SkiaText?>
var heart : SkPath?
var track : SkPath?
var progress : SkPath?
var measure : SkPathMeasure?
var frames : int

def geometry_init() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia - Path operations and measurement",size=int2(900,600))) |> skia_try
    paint=create_paint(PaintOptions())
    ink=create_paint(PaintOptions(color=0xffe8edf8u))
    resize(paths,5)
    var operations <- array(SkPathOp.Union,SkPathOp.Intersect,SkPathOp.Difference,SkPathOp.Xor,SkPathOp.ReverseDifference)
    for (i in range(5)) {
        let x=28.0+float(i)*176.0
        with_path() $(a : SkPath?) {
            a |> add_oval(float4(x+7.0,65.0,84.0,84.0))
            return with_path() $(b : SkPath?) {
                b |> add_oval(float4(x+47.0,65.0,84.0,84.0))
                var combined=path_op(a,b,operations[i]) |> skia_try
                paths[i]=combined
                return skia_ok()
            }
        } |> skia_try
    }
    heart=path_from_svg("M 112 337 C 42 271 7 370 112 448 C 217 370 182 271 112 337 Z") |> skia_try
    track=path_from_svg("M 300 400 C 400 225 595 500 815 330") |> skia_try
    measure=create_path_measure(track,PathMeasureOptions(precision=2.0)) |> skia_try
    progress=measure_segment(measure,measure_length(measure)*0.15,measure_length(measure)*0.72) |> skia_try
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=17.0)) $(font : SkFont?) {
        var names <- array("Union","Intersect","Difference","Xor","Reverse difference","SVG path data","Measure / segment / tangent","Skia paths: combine, measure, reuse")
        resize(labels,length(names))
        for (i in range(length(names))) {
            var text=shape_text(font,names[i],TextOptions()) |> skia_try
            labels[i]=text
        }
        return skia_ok()
    }
}
def geometry_draw(c : SkCanvas?) : SkiaStatus {
    c |> clear(0xff181c28u)
    c |> draw_text(labels[7],float2(28.0,18.0),ink)
    for (i in range(5)) {
        let x=28.0+float(i)*176.0
        paint |> reset_paint()
        paint |> set_antialias(true)
        paint |> set_color(0xff39455bu)
        paint |> set_stroke(true,1.5)
        c |> draw_oval(float4(x+7.0,65.0,84.0,84.0),paint)
        c |> draw_oval(float4(x+47.0,65.0,84.0,84.0),paint)
        paint |> set_stroke(false)
        paint |> set_color(0xff39b5f0u)
        c |> draw_path(paths[i],paint)
        c |> draw_text(labels[i],float2(x,177.0),ink)
    }
    paint |> set_color(0xff39455bu)
    c |> draw_rect(float4(28.0,235.0,844.0,1.0),paint)
    paint |> set_color(0xffff5d62u)
    c |> draw_path(heart,paint)
    paint |> set_stroke(true,8.0)
    paint |> set_stroke_cap(SkStrokeCap.Round)
    paint |> set_color(0xff39455bu)
    c |> draw_path(track,paint)
    paint |> set_color(0xff50d99au)
    c |> draw_path(progress,paint)
    let distance=measure_length(measure)*(0.3+float(frames%240)/600.0)
    let sample=sample_path(measure,distance)
    if (is_some(sample)) {
        let point=unwrap(sample)
        paint |> set_color(0xfff4d36du)
        paint |> set_stroke(true,3.0)
        c |> draw_line(point.position-point.tangent*25.0,point.position+point.tangent*35.0,paint)
        paint |> set_stroke(false)
        c |> draw_circle(point.position,9.0,paint)
    }
    c |> draw_text(labels[5],float2(40.0,485.0),ink)
    c |> draw_text(labels[6],float2(300.0,485.0),ink)
    return skia_ok()
}
def geometry_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return geometry_report(geometry_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) { return geometry_draw(c) }
    frames++
    if (frames==3) { print("PASS geometry frame 3\n") }
    return geometry_report(result)
}
[export]
def app_quit() {
    for (path in paths) { Skia_DeletePath(path) }
    for (text in labels) { destroy_text(text) }
    clear(paths); clear(labels)
    Skia_DeletePath(heart); heart=null
    Skia_DeletePath(track); track=null
    Skia_DeletePath(progress); progress=null
    Skia_DeletePathMeasure(measure); measure=null
    Skia_DeletePaint(paint); paint=null
    Skia_DeletePaint(ink); ink=null
    destroy_window(window); window=null
}
