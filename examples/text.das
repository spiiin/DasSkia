options gen2
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_try

var window : SkiaWindow?
var paint : SkPaint?
var text : SkiaText?
var frames : int
def initialize_text() : SkiaStatus {
    window = create_window(SkiaWindowOptions(title="dasSkia · Text and shaping",size=int2(900,600))) |> skia_try
    paint = create_paint(PaintOptions(color=0xffe8edf8u))
    // The font is released after this block. The shaped text owns what it needs.
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=32.0)) $(font : SkFont?) {
        text = shape_text(font,
            "Skia + HarfBuzz + ICU\n\nLatin: office — ffi — AV\nКириллица: Привет, мир!\nCombining marks: á é ö\nArabic: السلام عليكم — 123\nHebrew: שלום עולם — 456\n\nOne API for desktop and WebGL 2.",
            TextOptions(width=790.0,language="und")) |> skia_try
        return skia_ok()
    }
}
def report_text(result : SkiaStatus) : int {
    if (is_err(result)) {
        let e = unwrap_err(result)
        print("{e.operation}: {e.message}\n")
        return -1
    }
    return 0
}
[export]
def app_init() : int { return report_text(initialize_text()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result = window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        c |> draw_text(text,float2(40.0,32.0),paint)
        return skia_ok()
    }
    frames++
    if (frames == 3) {
        let metrics = text_metrics(text)
        print("PASS text frame 3; lines={metrics.lines}; glyphs={metrics.glyphs}; missing={metrics.missing_glyphs}\n")
    }
    return report_text(result)
}
[export]
def app_quit() {
    destroy_text(text); text = null
    Skia_DeletePaint(paint); paint = null
    destroy_window(window); window = null
}
