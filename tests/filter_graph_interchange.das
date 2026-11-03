options gen2
require dasskia/skia_filter_graph
require dasskia/skia_scope

def check_graph(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("filter_graph_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def graph_pixel(surface : SkSurface?; x,y : int) : uint {
    var color : uint
    Skia_ReadPixel(surface,x,y,color)
    return color
}
def verify_graph_fixture(picture : SkPicture?) : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(40,40))) |> skia_use
        let c=canvas(surface)
        c |> clear(0u)
        c |> draw_picture(picture)
        let left=graph_pixel(surface,8,16)
        let right=graph_pixel(surface,24,16)
        check_graph((left>>24)==255u && ((left>>16)&255u)>=190u && ((left>>16)&255u)<=192u && ((left>>8)&255u)>=63u && ((left>>8)&255u)<=65u && (left&255u)==0u &&
            ((right>>16)&255u)>=63u && ((right>>16)&255u)<=65u && ((right>>8)&255u)>=63u && ((right>>8)&255u)<=65u && (right&255u)>=190u && (right&255u)<=192u,
            "multi-input graph: image/picture sources, copied bindings, uniform snapshot and resource lifetime") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=load_picture("filter-graph-interchange.skp") |> with_picture() $(picture : SkPicture?) {
        return verify_graph_fixture(picture)
    }
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS filter graph interchange: runtime shader, multiple inputs, image and picture sources\n")
    return 0
}
