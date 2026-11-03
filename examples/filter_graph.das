options gen2
require dasskia/skia_filter_graph
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_scope
require math

var window : SkiaWindow?
var scene : SkPicture?
var warp : SkRuntimeEffectBuilder?
var layer_paint : SkPaint?
var mixed_paint : SkPaint?
var merged_paint : SkPaint?
var ink : SkPaint?
var labels : array<SkiaText?>
var frames : int
var compilations : int

def record_scene() {
    return record_picture(PictureOptions(bounds=float4(0.0,0.0,240.0,160.0))) $(c : SkCanvas?) {
        return skia_scope() {
            let paint : SkPaint? = with_paint(PaintOptions(color=0xff303b52u)) |> skia_use
            c |> draw_round_rect(float4(0.0,0.0,240.0,160.0),float2(18.0),paint)
            paint |> set_color(0xff39b5f0u)
            c |> draw_circle(float2(60.0,60.0),30.0,paint)
            paint |> set_color(0xff50d99au)
            c |> draw_round_rect(float4(120.0,30.0,80.0,60.0),float2(12.0),paint)
            let font : SkFont? = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=22.0)) |> skia_use
            let text : SkiaText? = font |> with_shaped_text("Group input",TextOptions()) |> skia_use
            paint |> set_color(0xffe8edf8u)
            c |> draw_text(text,float2(20.0,115.0),paint)
            return skia_ok()
        }
    }
}
def init_graph_resources() : SkiaStatus {
    return skia_scope() {
        let warp_effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader image; uniform float offset; half4 main(float2 p) \{ half4 c=image.eval(p+float2(offset,0)); return half4(c.bgr,c.a); \}") |> with_runtime_effect() |> skia_use
        compilations++
        warp=create_runtime_builder(warp_effect)
        let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
        var pixels <- array(0xffff5d62u,0xfff4d36du,0xffc990f0u,0xff39b5f0u)
        source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
        let image : SkImage? = source |> with_snapshot() |> skia_use
        let image_output : SkImageFilter? = image_source_filter(image,float4(0.0,0.0,240.0,160.0)) |> with_image_filter() |> skia_use
        let picture_output : SkImageFilter? = picture_source_filter(scene) |> with_image_filter() |> skia_use
        let mix_effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader original; uniform shader overlay; uniform float amount; half4 main(float2 p) \{ return mix(original.eval(p),overlay.eval(p),amount); \}") |> with_runtime_effect() |> skia_use
        compilations++
        let mix_builder : SkRuntimeEffectBuilder? = mix_effect |> with_runtime_builder() |> skia_use
        mix_builder |> set_uniform("amount",0.35) |> skia_try
        var names <- array("original","overlay")
        var inputs : array<SkImageFilter const?>
        push(inputs,picture_output); push(inputs,image_output)
        let mixed : SkImageFilter? = runtime_image_filter(mix_builder,names,inputs) |> with_image_filter() |> skia_use
        mixed_paint |> set_image_filter(mixed)
        clear(names); clear(inputs)
        var colors <- array(0xff39b5f0u,0xff50d99au,0xfff4d36du)
        let gradient : SkShader? = linear_gradient(float2(0.0),float2(240.0,0.0),colors) |> with_shader() |> skia_use
        let shader_output : SkImageFilter? = shader_source_filter(gradient) |> with_image_filter() |> skia_use
        let bounded_shader : SkImageFilter? = crop_filter(float4(0.0,0.0,240.0,160.0),shader_output) |> with_image_filter() |> skia_use
        let first : SkImageFilter? = matrix_transform_filter(matrix_scale(float2(0.65)),picture_output) |> with_image_filter() |> skia_use
        let second : SkImageFilter? = matrix_transform_filter(multiply(matrix_translation(float2(210.0,0.0)),matrix_scale(float2(0.65))),mixed) |> with_image_filter() |> skia_use
        let third : SkImageFilter? = matrix_transform_filter(multiply(matrix_translation(float2(420.0,0.0)),matrix_scale(float2(0.65))),bounded_shader) |> with_image_filter() |> skia_use
        let fourth : SkImageFilter? = matrix_transform_filter(multiply(matrix_translation(float2(630.0,0.0)),matrix_scale(float2(0.65))),image_output) |> with_image_filter() |> skia_use
        push(inputs,first); push(inputs,second); push(inputs,third); push(inputs,fourth)
        let merged : SkImageFilter? = merge_filters(inputs) |> with_image_filter() |> skia_use
        merged_paint |> set_image_filter(merged)
        return skia_ok()
    }
}
def graph_init() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia - Runtime image-filter graphs",size=int2(900,640))) |> skia_try
    layer_paint=create_paint(PaintOptions())
    mixed_paint=create_paint(PaintOptions())
    merged_paint=create_paint(PaintOptions())
    ink=create_paint(PaintOptions(color=0xffe8edf8u))
    scene=record_scene() |> skia_try
    init_graph_resources() |> skia_try
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=18.0)) $(font : SkFont?) {
        var names <- array("SkSL image filters / compose native filter graphs","Original group","SkSL / neighboring pixels","Two named inputs",
            "Merge + matrix transforms","Picture","Mixed inputs","Shader source","Image source","Source + sample radius + named inputs | desktop + web")
        resize(labels,length(names))
        for (i in range(length(names))) {
            var text=shape_text(font,names[i],TextOptions()) |> skia_try
            labels[i]=text
        }
        return skia_ok()
    }
}
def draw_filter_graph(c : SkCanvas?) : SkiaStatus {
    warp |> set_uniform("offset",sin(float(frames%360)*0.04)*12.0) |> skia_try
    runtime_image_filter(warp,"image",null,12.0) |> with_image_filter() $(filter : SkImageFilter?) {
        layer_paint |> set_image_filter(filter)
        return skia_ok()
    } |> skia_try
    c |> clear(0xff181c28u)
    c |> draw_text(labels[0],float2(40.0,28.0),ink)
    c |> draw_picture(scene,matrix_translation(float2(40.0,100.0)))
    c |> with_saved() $(saved : SkCanvas?) {
        saved |> translate(float2(340.0,100.0))
        saved |> clip_rect(float4(0.0,0.0,240.0,160.0))
        return saved |> with_layer(layer_paint) $(layer : SkCanvas?) {
            layer |> draw_picture(scene)
            return skia_ok()
        }
    } |> skia_try
    c |> with_saved() $(saved : SkCanvas?) {
        saved |> translate(float2(640.0,100.0))
        saved |> clip_rect(float4(0.0,0.0,240.0,160.0))
        saved |> draw_paint(mixed_paint)
        return skia_ok()
    } |> skia_try
    for (i in range(3)) { c |> draw_text(labels[i+1],float2(40.0+float(i)*300.0,292.0),ink) }
    c |> draw_text(labels[4],float2(40.0,355.0),ink)
    c |> with_saved() $(saved : SkCanvas?) {
        saved |> translate(float2(40.0,410.0))
        saved |> clip_rect(float4(0.0,0.0,820.0,125.0))
        saved |> draw_paint(merged_paint)
        return skia_ok()
    } |> skia_try
    for (i in range(4)) { c |> draw_text(labels[i+5],float2(40.0+float(i)*210.0,550.0),ink) }
    c |> draw_text(labels[9],float2(40.0,605.0),ink)
    return skia_ok()
}
def graph_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return graph_report(graph_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) { return draw_filter_graph(c) }
    frames++
    if (frames==3) { print("PASS filter graph frame 3; compilations={compilations}\n") }
    return graph_report(result)
}
[export]
def app_quit() {
    Skia_DeleteRuntimeBuilder(warp); warp=null
    Skia_PictureUnref(scene); scene=null
    Skia_DeletePaint(layer_paint); layer_paint=null
    Skia_DeletePaint(mixed_paint); mixed_paint=null
    Skia_DeletePaint(merged_paint); merged_paint=null
    Skia_DeletePaint(ink); ink=null
    for (text in labels) { destroy_text(text) }
    clear(labels)
    destroy_window(window); window=null
}
