options gen2
require daslib/defer
module skia_sdl_gl shared public
require dasskia/skia_boost public
struct SkiaWindowOptions {
    title : string = "dasSkia"
    size : int2 = int2(800,600)
    hidden : bool = false
}
def public create_window(settings : SkiaWindowOptions) {
    var window = Skia_NewWindow(settings.title,settings.size.x,settings.size.y,settings.hidden)
    if (window == null) { return err(skia_error("create_window",string(Skia_WindowError())),type<SkiaWindow?>) }
    return <- move_ok(window,type<SkiaError>)
}
def public destroy_window(window : SkiaWindow?) { Skia_DeleteWindow(window) }
def public poll_window(window : SkiaWindow?) : bool { return Skia_PollWindow(window) }
def public begin_frame(window : SkiaWindow?) {
    var canvas = Skia_BeginFrame(window)
    if (canvas == null) { return err(skia_error("begin_frame",string(Skia_WindowError())),type<SkCanvas?>) }
    return <- move_ok(canvas,type<SkiaError>)
}
def public present(window : SkiaWindow?) : SkiaStatus {
    if (!Skia_Present(window)) { return err(skia_error("present",string(Skia_WindowError())),type<SkiaUnit>) }
    return skia_ok()
}
def public with_frame(window : SkiaWindow?; blk : block<(canvas : SkCanvas?) : $Result<auto(TT);SkiaError>>) {
    var frame <- begin_frame(window)
    if (is_err(frame)) { return err(unwrap_err(frame),type<TT>) }
    var result : $Result<TT;SkiaError>
    static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(move_unwrap(frame)) } else { result <- blk(move_unwrap(frame)) }
    if (is_err(result)) { return <- result }
    let submitted = present(window)
    if (is_err(submitted)) { return err(unwrap_err(submitted),type<TT>) }
    return <- result
}

def public with_window(settings : SkiaWindowOptions; blk : block<(window : SkiaWindow?) : $Result<auto(TT);SkiaError>>) {
    var created <- create_window(settings)
    if (is_err(created)) { return err(unwrap_err(created),type<TT>) }
    let window = move_unwrap(created)
    var result : $Result<TT;SkiaError>
    {
        defer() { destroy_window(window) }
        static_if (typeinfo can_copy(type<$Result<TT;SkiaError>>)) { result = blk(window) } else { result <- blk(window) }
    }
    return <- result
}

// Ok(false) skips drawing/swapping; it is not an error or a successful draw.
def public prepare_frame(target : SkiaWindow?) {
    let state=Skia_PrepareWindowFrame(target)
    if (state<0) {return err(skia_error("prepare_frame",Skia_WindowError()),type<bool>)}
    return ok(state==1,type<SkiaError>)
}
def public window_context_generation(target : SkiaWindow?) : uint {return Skia_WindowContextGeneration(target)}
