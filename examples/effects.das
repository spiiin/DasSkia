options gen2
require dasskia/skia_effects
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_try

var window : SkiaWindow?
var paints : array<SkPaint?>
var labels : array<SkiaText?>
var ink : SkPaint?
var frames : int

def effects_init() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia - Shaders and filters",size=int2(900,640))) |> skia_try
    ink=create_paint(PaintOptions(color=0xffe8edf8u))
    resize(paints,9)
    for (i in range(9)) { paints[i]=create_paint(PaintOptions()) }
    var colors <- array(0xffff5d62u,0xffc990f0u,0xff39b5f0u)
    linear_gradient(float2(40.0,0.0),float2(270.0,0.0),colors) |> with_shader() $(s : SkShader?) {
        paints[0] |> set_shader(s)
        return skia_ok()
    } |> skia_try
    radial_gradient(float2(445.0,115.0),85.0,colors) |> with_shader() $(s : SkShader?) {
        paints[1] |> set_shader(s)
        return skia_ok()
    } |> skia_try
    var rainbow <- array(0xffff5d62u,0xfff4d36du,0xff50d99au,0xff39b5f0u,0xffc990f0u,0xffff5d62u)
    sweep_gradient(float2(745.0,115.0),0.0,360.0,rainbow) |> with_shader() $(s : SkShader?) {
        paints[2] |> set_shader(s)
        return skia_ok()
    } |> skia_try
    with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) $(source : SkSurface?) {
        var pixels <- array(0xff39b5f0u,0xff50d99au,0xff50d99au,0xff39b5f0u)
        source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
        source |> with_snapshot() $(image : SkImage?) {
            image_shader(image,ImageShaderOptions(tile_x=SkTileMode.Repeat,tile_y=SkTileMode.Repeat,
                local_matrix=matrix_scale(float2(18.0)))) |> with_shader() $(s : SkShader?) {
                paints[3] |> set_shader(s)
                return skia_ok()
            } |> skia_try
            return skia_ok()
        } |> skia_try
        return skia_ok()
    } |> skia_try
    var intervals <- array(14.0,10.0)
    dash_effect(intervals) |> with_path_effect() $(e : SkPathEffect?) {
        paints[4] |> set_path_effect(e)
        paints[4] |> set_color(0xfff4d36du)
        paints[4] |> set_stroke(true,8.0)
        paints[4] |> set_stroke_cap(SkStrokeCap.Round)
        return skia_ok()
    } |> skia_try
    drop_shadow_filter(float2(10.0,12.0),float2(8.0),0xaa000000u) |> with_image_filter() $(f : SkImageFilter?) {
        paints[5] |> set_image_filter(f)
        paints[5] |> set_color(0xffc990f0u)
        return skia_ok()
    } |> skia_try
    blur_mask(12.0) |> with_mask_filter() $(f : SkMaskFilter?) {
        paints[6] |> set_mask_filter(f)
        paints[6] |> set_color(0xff39b5f0u)
        return skia_ok()
    } |> skia_try
    lighting_color_filter(0xff80ff80u,0xff203020u) |> with_color_filter() $(f : SkColorFilter?) {
        paints[7] |> set_color_filter(f)
        paints[7] |> set_color(0xffff5d62u)
        return skia_ok()
    } |> skia_try
    conical_gradient(float2(710.0,490.0),5.0,float2(750.0,505.0),85.0,colors) |> with_shader() $(s : SkShader?) {
        paints[8] |> set_shader(s)
        return skia_ok()
    } |> skia_try
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=17.0)) $(font : SkFont?) {
        var names <- array("Linear gradient","Radial gradient","Sweep gradient","Image shader / repeat","Dash path effect","Drop shadow","Mask blur","Lighting color filter","Two-point conical")
        resize(labels,9)
        for (i in range(9)) { var text=shape_text(font,names[i],TextOptions()) |> skia_try; labels[i]=text }
        return skia_ok()
    }
}
def effects_draw(c : SkCanvas?) : SkiaStatus {
    c |> clear(0xff181c28u)
    c |> draw_round_rect(float4(40.0,45.0,230.0,140.0),float2(18.0),paints[0])
    c |> draw_circle(float2(445.0,115.0),70.0,paints[1])
    c |> draw_circle(float2(745.0,115.0),70.0,paints[2])
    c |> draw_round_rect(float4(40.0,255.0,230.0,120.0),float2(18.0),paints[3])
    c |> draw_line(float2(340.0,285.0),float2(550.0,285.0),paints[4])
    c |> draw_arc(float4(370.0,280.0,150.0,90.0),0.0,180.0,false,paints[4])
    c |> draw_round_rect(float4(640.0,265.0,200.0,95.0),float2(18.0),paints[5])
    c |> draw_circle(float2(155.0,510.0),50.0,paints[6])
    c |> draw_round_rect(float4(345.0,460.0,200.0,100.0),float2(18.0),paints[7])
    c |> draw_circle(float2(745.0,510.0),70.0,paints[8])
    for (i in range(9)) {
        c |> draw_text(labels[i],float2(40.0+float(i%3)*300.0,195.0+float(i/3)*195.0),ink)
    }
    return skia_ok()
}
def effects_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return effects_report(effects_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) { return effects_draw(c) }
    frames++
    if (frames==3) { print("PASS effects frame 3\n") }
    return effects_report(result)
}
[export]
def app_quit() {
    for (text in labels) { destroy_text(text) }
    for (paint in paints) { Skia_DeletePaint(paint) }
    clear(labels)
    clear(paints)
    Skia_DeletePaint(ink); ink=null
    destroy_window(window); window=null
}
