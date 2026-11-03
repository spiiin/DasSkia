options gen2
require dasskia/skia_boost
require dasskia/skia_scope

def check(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("test",message),type<SkiaUnit>) }
    return skia_ok()
}
def test_raster() : SkiaStatus {
    let invalid = create_raster_surface(RasterSurfaceOptions(size=int2(0,16)))
    check(is_err(invalid),"zero width must fail") |> skia_try
    let result = skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,64))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        let path : SkPath? = with_path() |> skia_use
        let c = canvas(surface)
        c |> clear(0xffffffffu)
        c |> draw_rect(float4(8.0,8.0,16.0,16.0),paint)
        let red = surface |> read_pixel(int2(12,12)) |> skia_try
        check(red == 0xffff0000u,"rectangle pixel") |> skia_try
        let white = surface |> read_pixel(int2(0,0)) |> skia_try
        check(white == 0xffffffffu,"background pixel") |> skia_try
        let before = Skia_SaveCount(c)
        let failed = c |> with_saved() $(saved : SkCanvas?) {
            saved |> translate(float2(32.0,0.0))
            Skia_Save(saved)
            return err(skia_error("body","expected"),type<SkiaUnit>)
        }
        check(is_err(failed) && Skia_SaveCount(c) == before,"restore count after body Err") |> skia_try
        path |> move_to(float2(30.0,30.0))
        path |> line_to(float2(60.0,30.0))
        path |> line_to(float2(30.0,60.0))
        path |> close_path()
        c |> draw_path(path,paint)
        let triangle = surface |> read_pixel(int2(35,35)) |> skia_try
        check(triangle == 0xffff0000u,"path pixel") |> skia_try
        check(is_err(read_pixel(surface,int2(-1,0))),"bounds rejection") |> skia_try
        surface |> save_png("raster-test.png") |> skia_try
        let image : SkImage? = with_image_file("raster-test.png") |> skia_use
        c |> clear(0xff000000u)
        c |> draw_image(image,float2(0.0,0.0))
        let loaded = surface |> read_pixel(int2(12,12)) |> skia_try
        check(loaded == 0xffff0000u,"PNG encode/decode roundtrip") |> skia_try
        let snapshot : SkImage? = surface |> with_snapshot() |> skia_use
        c |> clear(0xff0000ffu)
        c |> draw_image(snapshot,float2(0.0,0.0))
        let snap = surface |> read_pixel(int2(12,12)) |> skia_try
        check(snap == 0xffff0000u,"snapshot keeps old pixels") |> skia_try
        return skia_ok()
    }
    return result
}
[export]
def main() : int {
    let result = test_raster()
    if (is_err(result)) {
        let e = unwrap_err(result)
        print("FAIL {e.operation}: {e.message}\n")
        return 1
    }
    print("PASS raster: pixels, scopes, paths, PNG, snapshot\n")
    return 0
}
