options gen2
require dasskia/skia_sdl3
require dasskia/skia_scope
require daslib/defer

def check_interop(value : bool; message : string) : SkiaStatus {
    if (!value) {return err(skia_error("sdl_interop_test",message),type<SkiaUnit>)}
    return skia_ok()
}
def test_interop() : SkiaStatus {
    sdl_status(SDL_Init(SDL_INIT_VIDEO),"SDL_Init") |> skia_from_sdl() |> skia_try
    var result : SkiaStatus
    {
        defer() {SDL_Quit()}
        configure_sdl_gl() |> skia_try
        var window=SDL_CreateWindow("Borrowed SDL window",160,100,SDL_WINDOW_OPENGL|SDL_WINDOW_HIDDEN|SDL_WINDOW_RESIZABLE|SDL_WINDOW_HIGH_PIXEL_DENSITY)
        if (window==null) {return err(skia_error("SDL_CreateWindow",SDL_GetErrorCopy()),type<SkiaUnit>)}
        {
            defer() {SDL_DestroyWindow(window)}
            var context=SDL_GL_CreateContext(window)
            if (context==null) {return err(skia_error("SDL_GL_CreateContext",SDL_GetErrorCopy()),type<SkiaUnit>)}
            {
                defer() {SDL_GL_DestroyContext(context)}
                check_interop(is_err(attach_sdl_window(null,context)) && is_err(attach_sdl_window(window,null)),"null host handles rejected") |> skia_try
                var marker=SDL_MakeEvent()
                marker.event_type=SDL_EVENT_QUIT
                check_interop(SDL_PushEventRef(marker),"queue marker accepted") |> skia_try
                result=window |> with_sdl_target(context) $(target : SkiaSDLTarget?) {
                    return skia_scope() {
                    let size=sdl_frame_size(target) |> skia_try
                    check_interop(size.x>=160 && size.y>=100,"drawable pixel size") |> skia_try
                    check_interop(is_err(end_sdl_frame(target)) && is_err(read_sdl_frame_pixel(target,int2(0))),"frame state validation") |> skia_try
                    let paint : SkPaint? = with_paint(PaintOptions(color=0xff39b5f0u)) |> skia_use
                    target |> with_sdl_frame() $(c : SkCanvas?) {
                        check_interop(is_err(begin_sdl_frame(target)),"nested frame rejected") |> skia_try
                        c |> clear(0xff181c28u)
                        c |> draw_rect(float4(10.0,10.0,80.0,60.0),paint)
                        let pixel=target |> read_sdl_frame_pixel(int2(20,20)) |> skia_try
                        check_interop(pixel==0xff39b5f0u,"Ganesh draws on externally owned framebuffer") |> skia_try
                        return skia_ok()
                    } |> skia_try
                    // Host performs the swap explicitly.
                    sdl_status(SDL_GL_SwapWindow(window),"SDL_GL_SwapWindow") |> skia_from_sdl() |> skia_try
                    let failed=target |> with_sdl_frame() $(c : SkCanvas?) {
                        c |> clear(0xff000000u)
                        return err(skia_error("body","primary body error"),type<SkiaUnit>)
                    }
                    check_interop(is_err(failed) && unwrap_err(failed).operation=="body","body error remains primary") |> skia_try
                    // A body Err still ends/flushed the frame, allowing the next one.
                    target |> with_sdl_frame() $(c : SkCanvas?) {c |> clear(0xff50d99au);return skia_ok()} |> skia_try
                    var event=SDL_MakeEvent();var found=false
                    while (SDL_PollEventRef(event)) {if (event.event_type==SDL_EVENT_QUIT) {found=true}}
                    check_interop(found,"attach/begin/end never consume the event queue") |> skia_try
                    return skia_ok()
                    }
                }
                if (is_err(result)) {return result}
                check_interop((SDL_WasInit(SDL_INIT_VIDEO)&SDL_INIT_VIDEO)!=0u,"detach keeps SDL video initialized") |> skia_try
                sdl_status(SDL_GL_MakeCurrent(window,context),"SDL_GL_MakeCurrent after detach") |> skia_from_sdl() |> skia_try
                // Both host resources survived. Attach again and render/read back.
                result=window |> with_sdl_target(context) $(target : SkiaSDLTarget?) {
                    return target |> with_sdl_frame() $(c : SkCanvas?) {
                        c |> clear(0xffffb55du)
                        let pixel=target |> read_sdl_frame_pixel(int2(2,2)) |> skia_try
                        return check_interop(pixel==0xffffb55du,"reattach after detach")
                    }
                }
            }
        }
    }
    return result
}
[export]
def main() : int {
    let result=test_interop()
    if (is_err(result)) {let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return 1}
    print("PASS SDL interop: typed handles, borrowed ownership, pixels, host swap/events, frame errors, reattach\n")
    return 0
}
