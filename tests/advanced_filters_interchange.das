options gen2
require dasskia/skia_advanced_filters
require dasskia/skia_scope

def check_advanced(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("advanced_filters_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def adv_pixel(surface : SkSurface?; x,y : int) : uint {
    var color : uint
    Skia_ReadPixel(surface,x,y,color)
    return color
}
def verify_advanced_fixture(picture : SkPicture?) : SkiaStatus {
    return skia_scope() {
        let target : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,32))) |> skia_use
        let c=canvas(target);c |> clear(0u);c |> draw_picture(picture)
        let left=adv_pixel(target,8,16)
        let right=adv_pixel(target,48,16)
        check_advanced((left>>24)==255u && ((left>>16)&255u)>=126u && ((left>>16)&255u)<=129u && (left&65535u)==0u &&
            (right>>24)==255u && (right&255u)>=126u && (right&255u)<=129u && ((right>>8)&255u)>=126u && ((right>>16)&255u)>=126u,
            "serialized convolution and lighting retain graph inputs") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=load_picture("advanced-filters-interchange.skp") |> with_picture() $(picture : SkPicture?) { return verify_advanced_fixture(picture) }
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS advanced filters interchange: convolution and lighting\n")
    return 0
}
