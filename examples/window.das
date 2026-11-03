options gen2
require dasskia/skia_sdl_gl
require dasskia/skia_try
require math
var window : SkiaWindow?
var paint : SkPaint?
var frames : int
def start() : SkiaStatus {
    window = create_window(SkiaWindowOptions(title="dasSkia · OpenGL / WebGL 2")) |> skia_try
    paint = create_paint(PaintOptions(color=0xff36b5f0u))
    return skia_ok()
}
def report(result : SkiaStatus) : int {
    if (is_err(result)) {
        let e = unwrap_err(result)
        print("{e.operation}: {e.message}\n")
        return -1
    }
    return 0
}
[export]
def app_init() : int { return report(start()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result = window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_rect(float4(60.0,60.0,300.0,160.0),paint)
        let phase = float(frames) * 0.025
        c |> draw_circle(float2(460.0 + sin(phase)*80.0,340.0),100.0,paint)
        return skia_ok()
    }
    frames++
    if (frames == 3) { print("PASS frame 3\n") }
    return report(result)
}
[export]
def app_quit() {
    Skia_DeletePaint(paint); paint = null
    destroy_window(window); window = null
}
