options gen2
require dasskia/skia_sdl_texture
require dasskia/skia_paragraph
require dasskia/skia_scope
require math
var window : SDL_Window?
var renderer : SDL_Renderer?
var texture : SkiaSDLTexture?
var surface : SkSurface?
var paint : SkPaint?
var text : SkiaParagraph?
var frames : int

def start_texture() : SkiaStatus {
    sdl_status(SDL_Init(SDL_INIT_VIDEO),"SDL_Init") |> skia_from_sdl() |> skia_try
    window=SDL_CreateWindow("dasSDL3 Renderer + Skia raster",900,600,SDL_WINDOW_RESIZABLE|SDL_WINDOW_HIGH_PIXEL_DENSITY)
    if (window==null) {return err(skia_error("SDL_CreateWindow",SDL_GetErrorCopy()),type<SkiaUnit>)}
    renderer=SDL_CreateRenderer(window,"")
    if (renderer==null) {return err(skia_error("SDL_CreateRenderer",SDL_GetErrorCopy()),type<SkiaUnit>)}
    texture=create_sdl_texture(renderer,int2(900,600)) |> skia_try
    surface=create_raster_surface(RasterSurfaceOptions(size=int2(900,600))) |> skia_try
    paint=create_paint(PaintOptions(color=0xff39b5f0u))
    return skia_scope() {
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        var families <- array("Demo")
        let style : SkiaParagraphTextStyle? = with_paragraph_style(families,ParagraphTextOptions(size=28.0,color=0xffe8edf8u,height=1.4)) |> skia_use
        let builder : SkiaParagraphBuilder? = fonts |> with_paragraph_builder(style,ParagraphOptions()) |> skia_use
        builder |> add_paragraph_text("Skia raster → SDL_Texture

The application owns SDL_Renderer.
Skia draws on a CPU raster surface.
The host uploads, renders and presents.

Transparent pixels blend with SDL.
Привет • العربية • שלום") |> skia_try
        text=build_paragraph(builder) |> skia_try
        return skia_ok()
    }
}
def texture_report(result : $Result<auto(TextureReport);SkiaError>) : int {
    if (is_err(result)) {let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return -1}
    return 0
}
def draw_texture() : SkiaStatus {
    var size : int2
    sdl_status(SDL_GetWindowSizeInPixelsRef(window,size.x,size.y),"SDL_GetWindowSizeInPixels") |> skia_from_sdl() |> skia_try
    var paused=size.x<=0 || size.y<=0
    static_if (!SKIA_WEB) {paused=paused || (SDL_GetWindowFlags(window)&SDL_WINDOW_MINIMIZED)!=0ul}
    if (paused) {
        static_if (!SKIA_WEB) {SDL_Delay(16u)}
        return skia_ok()
    }
    if (surface_size(surface)!=size) {
        var replacement=create_raster_surface(RasterSurfaceOptions(size=size)) |> skia_try
        let resized=texture |> resize_sdl_texture(size)
        if (is_err(resized)) {Skia_SurfaceUnref(replacement);return resized}
        Skia_SurfaceUnref(surface);surface=replacement
    }
    let c=canvas(surface)
    c |> clear(0x00000000u)
    c |> draw_rect(float4(40.0,35.0,float(size.x)-80.0,12.0),paint)
    text |> layout_paragraph(max(100.0,float(size.x)-100.0)) |> skia_try
    c |> draw_paragraph(text,float2(50.0,85.0))
    Skia_SetColor(paint,0x80ffb55du)
    c |> draw_circle(float2(float(size.x)-70.0,float(size.y)-60.0),24.0,paint)
    Skia_SetColor(paint,0xff39b5f0u)
    texture |> upload_sdl_texture(surface) |> skia_try
    sdl_status(SDL_SetRenderDrawColor(renderer,24u,28u,40u,255u),"SDL_SetRenderDrawColor") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderClear(renderer),"SDL_RenderClear") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderTexture(renderer,sdl_texture(texture),null,null),"SDL_RenderTexture") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderPresent(renderer),"SDL_RenderPresent") |> skia_from_sdl() |> skia_try
    // The browser yields through RAF. Desktop must not busy-loop on this static demo.
    static_if (!SKIA_WEB) {SDL_Delay(16u)}
    frames++
    if (frames==3) {print("PASS SDL raster texture frame 3; host owns renderer and present\n")}
    return skia_ok()
}
[export]
def app_init() : int {return texture_report(start_texture())}
[export]
def app_frame() : int {
    var event=SDL_MakeEvent()
    while (SDL_PollEventRef(event)) {
        if (SDL_EventIsQuit(event) || SDL_EventIsEscape(event) ||
            (event.event_type==SDL_EVENT_WINDOW_CLOSE_REQUESTED && SDL_InputWindowID(event)==SDL_GetWindowID(window))) {return 1}
    }
    return texture_report(draw_texture())
}
[export]
def app_quit() {
    destroy_paragraph(text);text=null
    Skia_DeletePaint(paint);paint=null
    Skia_SurfaceUnref(surface);surface=null
    destroy_sdl_texture(texture);texture=null
    if (renderer!=null) {SDL_DestroyRenderer(renderer);renderer=null}
    if (window!=null) {SDL_DestroyWindow(window);window=null}
    SDL_Quit()
}
