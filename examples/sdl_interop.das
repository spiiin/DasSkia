options gen2
require dasskia/skia_sdl3
require dasskia/skia_paragraph
require dasskia/skia_scope
require math

var window : SDL_Window?
var context : SDL_GLContextState?
var target : SkiaSDLTarget?
var paint : SkPaint?
var text : SkiaParagraph?
var frames : int

def initialize_interop() : SkiaStatus {
    sdl_status(SDL_Init(SDL_INIT_VIDEO),"SDL_Init") |> skia_from_sdl() |> skia_try
    configure_sdl_gl() |> skia_try
    // dasSDL3 owns window/context. The same script runs on desktop and WASM.
    window=SDL_CreateWindow("dasSDL3 + Skia",900,600,SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE|SDL_WINDOW_HIGH_PIXEL_DENSITY)
    if (window==null) {return err(skia_error("SDL_CreateWindow",SDL_GetErrorCopy()),type<SkiaUnit>)}
    context=SDL_GL_CreateContext(window)
    if (context==null) {return err(skia_error("SDL_GL_CreateContext",SDL_GetErrorCopy()),type<SkiaUnit>)}
    // The host owns presentation pacing as well as swap. Unsupported VSync is
    // nonfatal; desktop also yields after each frame below.
    let vsync=SDL_GL_SetSwapInterval(1)
    target=attach_sdl_window(window,context) |> skia_try
    paint=create_paint(PaintOptions(color=0xff39b5f0u))
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=28.0,color=0xffe8edf8u,height=1.4)) |> skia_use
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(style,ParagraphOptions()) |> skia_use
        builder |> add_paragraph_text("dasSDL3 owns the window and GL context.\nSkia draws on the host framebuffer.\n\nThe application polls events and swaps.\nResize uses the current drawable pixel size.\n\nOne API: OpenGL 3.3 / WebGL 2.\nПривет • العربية • שלום") |> skia_try
        text=build_paragraph(builder) |> skia_try
        return skia_ok()
    }
}
def report_interop(result : $Result<auto(ReportValue);SkiaError>) : int {
    if (is_err(result)) {let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return -1}
    return 0
}
[export]
def app_init() : int {return report_interop(initialize_interop())}
[export]
def app_frame() : int {
    // Event loop remains in the application; Skia never polls it.
    var event=SDL_MakeEvent()
    while (SDL_PollEventRef(event)) {
        if (SDL_EventIsQuit(event) || SDL_EventIsEscape(event) ||
            (event.event_type==SDL_EVENT_WINDOW_CLOSE_REQUESTED && SDL_InputWindowID(event)==SDL_GetWindowID(window))) {return 1}
    }
    let ready=prepare_sdl_frame(target)
    if (is_err(ready)) {return report_interop(ready)}
    if (!unwrap(ready)) {return 0}
    let result=target |> with_sdl_frame() $(c : SkCanvas?) {
        let size=sdl_frame_size(target) |> skia_try
        c |> clear(0xff181c28u)
        c |> draw_rect(float4(40.0,35.0,float(size.x)-80.0,12.0),paint)
        text |> layout_paragraph(max(100.0,float(size.x)-100.0)) |> skia_try
        c |> draw_paragraph(text,float2(50.0,85.0))
        c |> draw_circle(float2(float(size.x)-70.0,float(size.y)-60.0),24.0,paint)
        return skia_ok()
    }
    if (is_err(result)) {return report_interop(result)}
    let swapped=sdl_status(SDL_GL_SwapWindow(window),"SDL_GL_SwapWindow") |> skia_from_sdl()
    // Browser frames already yield through requestAnimationFrame. Do not block
    // the web thread; desktop yields even when the driver ignores VSync.
    static_if (!SKIA_WEB) {SDL_Delay(1u)}
    frames++
    if (frames==3) {print("PASS SDL interop frame 3; host owns events and swap\n")}
    return report_interop(swapped)
}
[export]
def app_quit() {
    // Skia GPU objects go first; borrowed SDL handles stay live until detach.
    destroy_paragraph(text);text=null
    Skia_DeletePaint(paint);paint=null
    detach_sdl_window(target);target=null
    if (context!=null) {SDL_GL_DestroyContext(context);context=null}
    if (window!=null) {SDL_DestroyWindow(window);window=null}
    SDL_Quit()
}
