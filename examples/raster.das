options gen2
require dasskia/skia_boost
require dasskia/skia_scope
[export]
def main() : int {
    let result = skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(800,600))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xff36b5f0u)) |> skia_use
        let c = canvas(surface)
        c |> clear(0xff181c28u)
        c |> draw_rect(float4(60.0,60.0,300.0,160.0),paint)
        c |> draw_circle(float2(480.0,330.0),120.0,paint)
        surface |> save_png("dasSkia.png") |> skia_try
        return skia_ok()
    }
    if (is_err(result)) {
        let e = unwrap_err(result)
        print("{e.operation}: {e.message}\n")
        return 1
    }
    print("Wrote dasSkia.png\n")
    return 0
}
