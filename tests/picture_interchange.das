options gen2
require dasskia/skia_picture
require dasskia/skia_scope

def check_picture(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("picture_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def verify_fixture(picture : SkPicture?) : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(96,96))) |> skia_use
        let c=canvas(surface)
        c |> clear(0u)
        c |> draw_picture(picture)
        let red=surface |> read_pixel(int2(12,12)) |> skia_try
        let blue=surface |> read_pixel(int2(64,24)) |> skia_try
        let imred=surface |> read_pixel(int2(12,52)) |> skia_try
        let green=surface |> read_pixel(int2(36,52)) |> skia_try
        let imblue=surface |> read_pixel(int2(12,76)) |> skia_try
        let white=surface |> read_pixel(int2(36,76)) |> skia_try
        let mid=surface |> read_pixel(int2(64,80)) |> skia_try
        check_picture(red==0xffff0000u && blue==0xff0000ffu && imred==0xffff0000u && green==0xff00ff00u &&
            imblue==0xff0000ffu && white==0xffffffffu && ((mid>>16)&255u)>115u && (mid&255u)>115u,"recorded geometry, image and gradient pixels") |> skia_try
        var text_pixels : array<uint>
        resize(text_pixels,40*18)
        surface |> read_pixels(int4(44,54,40,18),text_pixels) |> skia_try
        var ink=0
        for (pixel in text_pixels) { if ((pixel>>24)>64u && (pixel&255u)>200u) { ink++ } }
        check_picture(ink>30,"recorded embedded font text ink") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=load_picture("picture-interchange.skp") |> with_picture() $(picture : SkPicture?) {
        return verify_fixture(picture)
    }
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS picture interchange: images, embedded text and gradient\n")
    return 0
}
