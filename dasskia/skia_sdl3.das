options gen2
require daslib/defer
module skia_sdl3 shared public
require skia_sdl3_native public
require dasskia/skia_boost public
require dassdl3/sdl3_result public

// Explicit conversion of the SDL error domain; preserves operation/message.
def public skia_from_sdl(var value : $Result<auto(SdlValue);SdlError>) {
    if (is_err(value)) {let e=unwrap_err(value);return err(skia_error(e.operation,e.message),type<SdlValue>)}
    var payload <- move_unwrap(value)
    return <- move_ok(payload,type<SkiaError>)
}
def public configure_sdl_gl() : SkiaStatus {
    if (!Skia_ConfigureSDLGL()) {return err(skia_error("configure_sdl_gl",Skia_WindowError()),type<SkiaUnit>)}
    return skia_ok()
}
def public attach_sdl_window(window : SDL_Window?; context : SDL_GLContextState?) {
    var target=Skia_AttachSDLWindow(window,context)
    if (target==null) {return err(skia_error("attach_sdl_window",Skia_WindowError()),type<SkiaSDLTarget?>)}
    return <- move_ok(target,type<SkiaError>)
}
def public detach_sdl_window(target : SkiaSDLTarget?) {Skia_DetachSDLWindow(target)}
def public begin_sdl_frame(target : SkiaSDLTarget?) {
    var c=Skia_BeginSDLFrame(target)
    if (c==null) {return err(skia_error("begin_sdl_frame",Skia_WindowError()),type<SkCanvas?>)}
    return <- move_ok(c,type<SkiaError>)
}
def public end_sdl_frame(target : SkiaSDLTarget?) : SkiaStatus {
    if (!Skia_EndSDLFrame(target)) {return err(skia_error("end_sdl_frame",Skia_WindowError()),type<SkiaUnit>)}
    return skia_ok()
}
def public sdl_frame_size(target : SkiaSDLTarget?) {
    var size : int2
    if (!Skia_SDLFrameSize(target,size.x,size.y)) {return err(skia_error("sdl_frame_size",Skia_WindowError()),type<int2>)}
    return ok(size,type<SkiaError>)
}
def public read_sdl_frame_pixel(target : SkiaSDLTarget?; position : int2) {
    var color : uint
    if (!Skia_ReadSDLFramePixel(target,position.x,position.y,color)) {return err(skia_error("read_sdl_frame_pixel",Skia_WindowError()),type<uint>)}
    return ok(color,type<SkiaError>)
}
def public with_sdl_target(window : SDL_Window?; context : SDL_GLContextState?; blk : block<(target : SkiaSDLTarget?) : $Result<auto(TargetBody);SkiaError>>) {
    var made <- attach_sdl_window(window,context)
    if (is_err(made)) {return err(unwrap_err(made),type<TargetBody>)}
    let target=move_unwrap(made)
    var result : $Result<TargetBody;SkiaError>
    {
        defer() {detach_sdl_window(target)}
        static_if (typeinfo can_copy(type<$Result<TargetBody;SkiaError>>)) {result=blk(target)} else {result <- blk(target)}
    }
    return <- result
}
def public with_sdl_frame(target : SkiaSDLTarget?; blk : block<(canvas : SkCanvas?) : $Result<auto(FrameBody);SkiaError>>) {
    var begun <- begin_sdl_frame(target)
    if (is_err(begun)) {return err(unwrap_err(begun),type<FrameBody>)}
    let c=move_unwrap(begun)
    var result : $Result<FrameBody;SkiaError>
    {
        defer() {
            let ended=end_sdl_frame(target)
            if (is_err(ended) && is_ok(result)) {result <- err(unwrap_err(ended),type<FrameBody>)}
        }
        static_if (typeinfo can_copy(type<$Result<FrameBody;SkiaError>>)) {result=blk(c)} else {result <- blk(c)}
    }
    return <- result
}

// Ok(false) skips drawing/swapping; it is not an error or a successful draw.
def public prepare_sdl_frame(target : SkiaSDLTarget?) {
    let state=Skia_PrepareSDLFrame(target)
    if (state<0) {return err(skia_error("prepare_sdl_frame",Skia_WindowError()),type<bool>)}
    return ok(state==1,type<SkiaError>)
}
def public sdl_context_generation(target : SkiaSDLTarget?) : uint {return Skia_SDLContextGeneration(target)}
