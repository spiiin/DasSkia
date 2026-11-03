options gen2
require dasskia/skia_sdl_gl
require dasskia/skia_scope
def test_gl() : SkiaStatus {
    return with_window(SkiaWindowOptions(title="dasSkia GL test",size=int2(128,128),hidden=!SKIA_WEB)) $(window : SkiaWindow?) {
        return with_paint(PaintOptions(color=0xffff0000u,antialias=false)) $(paint : SkPaint?) {
            for (frame in 0 .. 3) {
                let c = window |> begin_frame() |> skia_try
                c |> clear(0xff0000ffu)
                c |> draw_rect(float4(8.0,8.0,32.0,32.0),paint)
                var color : uint
                let read = Skia_ReadWindowPixel(window,12,12,color)
                if (!read || color != 0xffff0000u) {
                    let detail = Skia_WindowError()
                    return err(skia_error("gpu_pixel","read={read}; ARGB={color}; frame={frame}; {detail}"),type<SkiaUnit>)
                }
                window |> present() |> skia_try
                if (frame == 0 && !Skia_ResizeWindow(window,160,144)) {
                    return err(skia_error("resize",string(Skia_WindowError())),type<SkiaUnit>)
                }
                poll_window(window)
            }
            return skia_ok()
        }
    }
}
[export]
def main() : int {
    let result = test_gl()
    if (is_err(result)) {
        let e = unwrap_err(result)
        print("FAIL {e.operation}: {e.message}\n")
        return 1
    }
    print("PASS SDL GL: GPU pixels, resize, presentation\n")
    return 0
}
