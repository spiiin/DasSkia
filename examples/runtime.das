options gen2
require dasskia/skia_runtime
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_try

var window : SkiaWindow?
var wave : SkRuntimeEffectBuilder?
var warp : SkRuntimeEffectBuilder?
var wave_paint : SkPaint?
var warp_paint : SkPaint?
var filtered : SkPaint?
var plain : SkPaint?
var ink : SkPaint?
var blends : array<SkPaint?>
var labels : array<SkiaText?>
var frames : int
var compilations : int

def runtime_init() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia - SkSL runtime effects",size=int2(900,640))) |> skia_try
    wave_paint=create_paint(PaintOptions())
    warp_paint=create_paint(PaintOptions())
    filtered=create_paint(PaintOptions())
    plain=create_paint(PaintOptions())
    ink=create_paint(PaintOptions(color=0xffe8edf8u))
    compile_runtime_shader("uniform float2 origin; uniform float2 size; uniform float phase; half4 main(float2 p) \{ float2 uv=(p-origin)/size; float t=0.5+0.5*cos((uv.x+uv.y)*12+phase); return half4(mix(float3(0.22,0.71,0.94),float3(1,0.36,0.38),t),1); \}") |> with_runtime_effect() $(effect : SkRuntimeEffect?) {
        compilations++
        wave=create_runtime_builder(effect)
        wave |> set_uniform("origin",float2(40.0,85.0)) |> skia_try
        wave |> set_uniform("size",float2(240.0,190.0)) |> skia_try
        return skia_ok()
    } |> skia_try
    compile_runtime_shader("uniform shader base; uniform float phase; half4 main(float2 p) \{ return base.eval(p+float2(sin(p.y*0.05+phase)*30,0)); \}") |> with_runtime_effect() $(effect : SkRuntimeEffect?) {
        compilations++
        warp=create_runtime_builder(effect)
        var colors <- array(0xff39b5f0u,0xff50d99au,0xfff4d36du)
        linear_gradient(float2(340.0,0.0),float2(580.0,0.0),colors) |> with_shader() $(base : SkShader?) {
            warp |> set_child("base",base) |> skia_try
            return skia_ok()
        } |> skia_try
        return skia_ok()
    } |> skia_try
    compile_runtime_color_filter("half4 main(half4 c) \{ return half4(c.bgr,c.a); \}") |> with_runtime_effect() $(effect : SkRuntimeEffect?) {
        compilations++
        return effect |> with_runtime_builder() $(builder : SkRuntimeEffectBuilder?) {
            return runtime_color_filter(builder) |> with_color_filter() $(filter : SkColorFilter?) {
                filtered |> set_color_filter(filter)
                return skia_ok()
            }
        }
    } |> skia_try
    resize(blends,3)
    compile_runtime_blender("uniform float ratio; half4 main(half4 s,half4 d) \{ return mix(d,s,ratio); \}") |> with_runtime_effect() $(effect : SkRuntimeEffect?) {
        compilations++
        return effect |> with_runtime_builder() $(builder : SkRuntimeEffectBuilder?) {
            for (i in range(3)) {
                blends[i]=create_paint(PaintOptions(color=0xffff0000u))
                builder |> set_uniform("ratio",0.25+float(i)*0.25) |> skia_try
                runtime_blender(builder) |> with_blender() $(blend : SkBlender?) {
                    blends[i] |> set_blender(blend)
                    return skia_ok()
                } |> skia_try
            }
            return skia_ok()
        }
    } |> skia_try
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=18.0)) $(font : SkFont?) {
        var names <- array("SkSL runtime effects / compile once","Animated shader","Child shader / coordinate warp","Runtime color filter",
            "Blender / ratio 0.25","Blender / ratio 0.50","Blender / ratio 0.75","Shared API: raster, OpenGL and WebGL 2")
        resize(labels,length(names))
        for (i in range(length(names))) {
            var text=shape_text(font,names[i],TextOptions()) |> skia_try
            labels[i]=text
        }
        return skia_ok()
    }
}
def update_runtime() : SkiaStatus {
    let phase=float(frames%360)*0.03
    wave |> set_uniform("phase",phase) |> skia_try
    warp |> set_uniform("phase",phase) |> skia_try
    runtime_shader(wave) |> with_shader() $(shader : SkShader?) {
        wave_paint |> set_shader(shader)
        return skia_ok()
    } |> skia_try
    runtime_shader(warp) |> with_shader() $(shader : SkShader?) {
        warp_paint |> set_shader(shader)
        return skia_ok()
    } |> skia_try
    return skia_ok()
}
def runtime_draw(c : SkCanvas?) : SkiaStatus {
    update_runtime() |> skia_try
    c |> clear(0xff181c28u)
    c |> draw_text(labels[0],float2(40.0,28.0),ink)
    c |> draw_round_rect(float4(40.0,85.0,240.0,190.0),float2(18.0),wave_paint)
    c |> draw_round_rect(float4(340.0,85.0,240.0,190.0),float2(18.0),warp_paint)
    var colors <- array(0xffff5d62u,0xff50d99au,0xfff4d36du)
    for (i in range(3)) {
        plain |> set_color(colors[i])
        filtered |> set_color(colors[i])
        let y=85.0+float(i)*63.0
        c |> draw_rect(float4(640.0,y,120.0,63.0),plain)
        c |> draw_rect(float4(760.0,y,120.0,63.0),filtered)
    }
    for (i in range(3)) {
        let x=40.0+float(i)*300.0
        c |> draw_text(labels[i+1],float2(x,298.0),ink)
        plain |> set_color(0xff0000ffu)
        c |> draw_round_rect(float4(x,395.0,240.0,130.0),float2(18.0),plain)
        c |> draw_circle(float2(x+120.0,460.0),45.0,blends[i])
        c |> draw_text(labels[i+4],float2(x,548.0),ink)
    }
    c |> draw_text(labels[7],float2(40.0,605.0),ink)
    return skia_ok()
}
def runtime_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return runtime_report(runtime_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) { return runtime_draw(c) }
    frames++
    if (frames==3) { print("PASS runtime frame 3; compilations={compilations}\n") }
    return runtime_report(result)
}
[export]
def app_quit() {
    Skia_DeleteRuntimeBuilder(wave); wave=null
    Skia_DeleteRuntimeBuilder(warp); warp=null
    Skia_DeletePaint(wave_paint); wave_paint=null
    Skia_DeletePaint(warp_paint); warp_paint=null
    Skia_DeletePaint(filtered); filtered=null
    Skia_DeletePaint(plain); plain=null
    Skia_DeletePaint(ink); ink=null
    for (paint in blends) { Skia_DeletePaint(paint) }
    for (text in labels) { destroy_text(text) }
    clear(blends); clear(labels)
    destroy_window(window); window=null
}
