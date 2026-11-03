options gen2
require dasskia/skia_picture
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var original : SkPicture?
var restored : SkPicture?
var pattern : SkPaint?
var translucent : SkPaint?
var ink : SkPaint?
var labels : array<SkiaText?>
var frames : int
var recordings : int

def record_badge() {
    return record_picture(PictureOptions(bounds=float4(0.0,0.0,200.0,140.0))) $(c : SkCanvas?) {
        recordings++
        return skia_scope() {
            let paint : SkPaint? = with_paint(PaintOptions(color=0xff303b52u)) |> skia_use
            c |> draw_round_rect(float4(0.0,0.0,200.0,140.0),float2(18.0),paint)
            paint |> set_color(0xff39b5f0u)
            c |> draw_circle(float2(45.0,48.0),27.0,paint)
            paint |> set_color(0xff50d99au)
            c |> draw_circle(float2(81.0,48.0),27.0,paint)
            let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
            var pixels <- array(0xffff5d62u,0xfff4d36du,0xffc990f0u,0xff39b5f0u)
            source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
            let image : SkImage? = source |> with_snapshot() |> skia_use
            c |> draw_image_to(image,float4(140.0,24.0,40.0,40.0))
            let font : SkFont? = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=21.0)) |> skia_use
            let text : SkiaText? = font |> with_shaped_text("Record once.",TextOptions()) |> skia_use
            paint |> set_color(0xffe8edf8u)
            c |> draw_text(text,float2(18.0,98.0),paint)
            return skia_ok()
        }
    }
}
def picture_init() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia - Recorded pictures",size=int2(900,640))) |> skia_try
    original=record_badge() |> skia_try
    var bytes=serialize_picture(original) |> skia_try
    restored=picture_from_bytes(bytes) |> skia_try
    let byte_count=length(bytes)
    clear(bytes)
    pattern=create_paint(PaintOptions())
    translucent=create_paint(PaintOptions())
    translucent |> set_alpha(0.7)
    ink=create_paint(PaintOptions(color=0xffe8edf8u))
    picture_shader(restored,PictureShaderOptions(local_matrix=matrix_scale(float2(0.4)))) |> with_shader() $(shader : SkShader?) {
        pattern |> set_shader(shader)
        return skia_ok()
    } |> skia_try
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=18.0)) $(font : SkFont?) {
        let stats=picture_stats(original)
        var names <- array("SkPicture: record once, replay anywhere","Original recording","Binary roundtrip","Transform + opacity",
            "Picture shader / repeated tiles","{stats.operations} recorded operations | {byte_count} serialized bytes | desktop + web")
        resize(labels,length(names))
        for (i in range(length(names))) {
            var text=shape_text(font,names[i],TextOptions()) |> skia_try
            labels[i]=text
        }
        return skia_ok()
    }
}
def picture_draw(c : SkCanvas?) : SkiaStatus {
    c |> clear(0xff181c28u)
    c |> draw_text(labels[0],float2(40.0,28.0),ink)
    c |> draw_picture(original,matrix_translation(float2(40.0,100.0)))
    c |> draw_picture(restored,matrix_translation(float2(340.0,100.0)))
    let transform=multiply(matrix_translation(float2(740.0,170.0)),
        multiply(matrix_rotation(-12.0),matrix_translation(float2(-100.0,-70.0))))
    c |> draw_picture(original,transform,translucent)
    for (i in range(3)) { c |> draw_text(labels[i+1],float2(40.0+float(i)*300.0,275.0),ink) }
    c |> draw_text(labels[4],float2(40.0,345.0),ink)
    c |> draw_round_rect(float4(40.0,390.0,820.0,170.0),float2(18.0),pattern)
    c |> draw_text(labels[5],float2(40.0,593.0),ink)
    return skia_ok()
}
def picture_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return picture_report(picture_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) { return picture_draw(c) }
    frames++
    if (frames==3) { print("PASS picture frame 3; recordings={recordings}\n") }
    return picture_report(result)
}
[export]
def app_quit() {
    Skia_PictureUnref(original); original=null
    Skia_PictureUnref(restored); restored=null
    Skia_DeletePaint(pattern); pattern=null
    Skia_DeletePaint(translucent); translucent=null
    Skia_DeletePaint(ink); ink=null
    for (text in labels) { destroy_text(text) }
    clear(labels)
    destroy_window(window); window=null
}
