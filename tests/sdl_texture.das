options gen2
require dasskia/skia_sdl_texture
require dasskia/skia_scope
require math
require daslib/defer

def check_texture(value : bool; message : string) : SkiaStatus {
    if (!value) {return err(skia_error("texture_test",message),type<SkiaUnit>)}
    return skia_ok()
}
def pixel_near(bytes : array<uint8>; width,x,y,r,g,b : int) : bool {
    let i=(y*width+x)*4
    return abs(int(bytes[i])-r)<=2 && abs(int(bytes[i+1])-g)<=2 && abs(int(bytes[i+2])-b)<=2
}
def check_texture_pixels(renderer : SDL_Renderer?; green : bool) : SkiaStatus {
    let image=SDL_ReadPixelsOwned(renderer)
    if (image==null) {return err(skia_error("SDL_ReadPixelsOwned",SDL_GetErrorCopy()),type<SkiaUnit>)}
    {
    defer() {SDL_DestroySurface(image)}
    var w,h : int
    sdl_status(SDL_SurfaceSizeRef(image,w,h),"SDL_SurfaceSizeRef") |> skia_from_sdl() |> skia_try
    var bytes : array<uint8>;resize(bytes,w*h*4)
    sdl_status(SDL_CopySurfaceRGBA8(image,bytes,w*4),"SDL_CopySurfaceRGBA8") |> skia_from_sdl() |> skia_try
    if (green) {return check_texture(pixel_near(bytes,w,w/2,h/2,80,217,154),"resized/reuploaded green pixels")}
    check_texture(pixel_near(bytes,w,0,0,0,0,255),"transparent source preserves renderer background") |> skia_try
    check_texture(pixel_near(bytes,w,w/5,h/4,57,181,240),"RGBA channel order and opaque pixels") |> skia_try
    return check_texture(pixel_near(bytes,w,w-3,h/2,128,32,127),"premultiplied Skia alpha converts to standard SDL blend")
    }
}
def render_texture(renderer : SDL_Renderer?; texture : SkiaSDLTexture?) : SkiaStatus {
    sdl_status(SDL_SetRenderDrawColor(renderer,0u,0u,255u,255u),"SDL_SetRenderDrawColor") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderClear(renderer),"SDL_RenderClear") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderTexture(renderer,sdl_texture(texture),null,null),"SDL_RenderTexture") |> skia_from_sdl() |> skia_try
    return skia_ok()
}
def texture_tests() : SkiaStatus {
    sdl_status(SDL_Init(SDL_INIT_VIDEO),"SDL_Init") |> skia_from_sdl() |> skia_try
    {
    defer() {SDL_Quit()}
    var flags=0ul
    static_if (!SKIA_WEB) {flags=SDL_WINDOW_HIDDEN}
    let window=SDL_CreateWindow("Skia raster upload test",64,48,flags)
    if (window==null) {return err(skia_error("SDL_CreateWindow",SDL_GetErrorCopy()),type<SkiaUnit>)}
    {
    defer() {SDL_DestroyWindow(window)}
    let renderer=SDL_CreateRenderer(window,"")
    if (renderer==null) {return err(skia_error("SDL_CreateRenderer",SDL_GetErrorCopy()),type<SkiaUnit>)}
    {
    defer() {SDL_DestroyRenderer(renderer)}
    check_texture(is_err(create_sdl_texture(null,int2(13,9))) && is_err(create_sdl_texture(renderer,int2(0,9))),"invalid creation rejected") |> skia_try
    let result=renderer |> with_sdl_texture(int2(13,9)) $(texture : SkiaSDLTexture?) {
        return skia_scope() {
            let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(13,9))) |> skia_use
            let c=canvas(surface)
            c |> clear(0u)
            let paint : SkPaint? = with_paint(PaintOptions(color=0xff39b5f0u,antialias=false,blend_mode=SkBlendMode.Src)) |> skia_use
            c |> draw_rect(float4(1.0,1.0,4.0,4.0),paint)
            Skia_SetColor(paint,0x80ff4000u)
            c |> draw_rect(float4(7.0,0.0,6.0,9.0),paint)
            texture |> upload_sdl_texture(surface) |> skia_try
            let original=sdl_texture(texture)
            check_texture(is_err(resize_sdl_texture(texture,int2(0,9))) && sdl_texture(texture)==original,"failed resize preserves texture") |> skia_try
            texture |> resize_sdl_texture(int2(13,9)) |> skia_try
            check_texture(sdl_texture(texture)==original,"same-size resize preserves texture") |> skia_try
            check_texture(is_err(upload_sdl_texture(texture,null)),"null raster rejected") |> skia_try
            render_texture(renderer,texture) |> skia_try
            check_texture_pixels(renderer,false) |> skia_try
            texture |> resize_sdl_texture(int2(5,3)) |> skia_try
            let size=sdl_texture_size(texture) |> skia_try
            check_texture(size==int2(5,3) && is_err(upload_sdl_texture(texture,surface)),"resize size and mismatch rejection") |> skia_try
            let resized : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(5,3))) |> skia_use
            canvas(resized) |> clear(0xff50d99au)
            texture |> upload_sdl_texture(resized) |> skia_try
            render_texture(renderer,texture) |> skia_try
            check_texture_pixels(renderer,true) |> skia_try
            return skia_ok()
        }
    }
    if (is_err(result)) {return result}
    // Scope cleanup and body Err never destroy the host renderer.
    let body=renderer |> with_sdl_texture(int2(3,2)) $(texture : SkiaSDLTexture?) {return err(skia_error("body","primary"),type<SkiaUnit>)}
    check_texture(is_err(body) && unwrap_err(body).operation=="body","body Err preserved") |> skia_try
    sdl_status(SDL_RenderClear(renderer),"host renderer survives texture deletion") |> skia_from_sdl() |> skia_try
    sdl_status(SDL_RenderPresent(renderer),"host owns present") |> skia_from_sdl() |> skia_try
    return skia_ok()
    }
    }
    }
}
[export]
def main() : int {
    let result=texture_tests()
    if (is_err(result)) {let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return 1}
    print("PASS SDL raster texture: RGBA/alpha pixels, resize, errors, borrowed renderer, scope cleanup\n")
    return 0
}
