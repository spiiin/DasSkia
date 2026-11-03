options gen2
require dasskia/skia_filter_graph
require dasskia/skia_scope
require math

def check_graph(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("filter_graph_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def graph_pixel(surface : SkSurface?; x,y : int) : uint {
    var color : uint
    Skia_ReadPixel(surface,x,y,color)
    return color
}
def test_single_and_radius() : SkiaStatus {
    return skia_scope() {
        let effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader source; uniform float gain; half4 main(float2 p) \{ half4 c=source.eval(p); return half4(c.bgr*gain,c.a); \}") |> with_runtime_effect() |> skia_use
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        let blue : SkShader? = solid_shader(0xff0000ffu) |> with_shader() |> skia_use
        builder |> set_child("source",blue) |> skia_try
        builder |> set_uniform("gain",0.5) |> skia_try
        let first : SkImageFilter? = runtime_image_filter(builder) |> with_image_filter() |> skia_use
        builder |> set_uniform("gain",1.0) |> skia_try
        let second : SkImageFilter? = runtime_image_filter(builder,"source") |> with_image_filter() |> skia_use
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,64))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        let c=canvas(surface)
        paint |> set_image_filter(first)
        c |> clear(0u)
        c |> draw_rect(float4(8.0,8.0,16.0,16.0),paint)
        let dim=graph_pixel(surface,12,12)
        check_graph((dim&255u)>=127u && (dim&255u)<=129u && ((dim>>16)&255u)==0u,"automatic source binding and immutable uniforms") |> skia_try
        paint |> set_image_filter(second)
        c |> clear(0u)
        c |> draw_rect(float4(8.0,8.0,16.0,16.0),paint)
        check_graph(graph_pixel(surface,12,12)==0xff0000ffu,"explicit source binding") |> skia_try
        let original : SkShader? = runtime_shader(builder) |> with_shader() |> skia_use
        paint |> set_image_filter()
        paint |> set_shader(original)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,12,12)==0xffff0000u,"dynamic filter binding does not mutate original builder child") |> skia_try
        paint |> reset_paint()
        paint |> set_antialias(false)
        paint |> set_color(0xffff0000u)
        let shift_effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader source; half4 main(float2 p) \{ return source.eval(p+float2(8,0)); \}") |> with_runtime_effect() |> skia_use
        let shift_builder : SkRuntimeEffectBuilder? = shift_effect |> with_runtime_builder() |> skia_use
        let shifted : SkImageFilter? = runtime_image_filter(shift_builder,"source",null,8.0) |> with_image_filter() |> skia_use
        paint |> set_image_filter(shifted)
        c |> clear(0u)
        c |> with_saved() $(saved : SkCanvas?) {
            saved |> clip_rect(float4(0.0,0.0,16.0,64.0))
            saved |> draw_rect(float4(20.0,20.0,16.0,16.0),paint)
            return skia_ok()
        } |> skia_try
        check_graph(graph_pixel(surface,14,25)==0xffff0000u && graph_pixel(surface,10,25)==0u,"sample radius captures source beyond output clip") |> skia_try
        let offset : SkImageFilter? = offset_filter(float2(10.0,0.0)) |> with_image_filter() |> skia_use
        let chained : SkImageFilter? = runtime_image_filter(builder,"source",offset) |> with_image_filter() |> skia_use
        paint |> set_image_filter(chained)
        c |> clear(0u)
        c |> draw_rect(float4(8.0,8.0,16.0,16.0),paint)
        check_graph(graph_pixel(surface,10,12)==0u && graph_pixel(surface,20,12)==0xff0000ffu,"explicit input filter chain") |> skia_try
        var negative <- runtime_image_filter(builder,"source",null,-1.0)
        var nan <- runtime_image_filter(builder,"source",null,sqrt(-1.0))
        var missing <- runtime_image_filter(builder,"missing")
        check_graph(is_err(negative) && is_err(nan) && is_err(missing),"invalid radius/name") |> skia_try
        return skia_ok()
    }
}
def test_group_layer() : SkiaStatus {
    return skia_scope() {
        let effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader source; half4 main(float2 p) \{ return 0.5*(source.eval(p-float2(4,0))+source.eval(p+float2(4,0))); \}") |> with_runtime_effect() |> skia_use
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        let filter : SkImageFilter? = runtime_image_filter(builder,"source",null,4.0) |> with_image_filter() |> skia_use
        let layer_paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
        let draw : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        layer_paint |> set_image_filter(filter)
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,64))) |> skia_use
        let c=canvas(surface)
        c |> clear(0u)
        let count=Skia_SaveCount(c)
        c |> with_layer(layer_paint) $(layer : SkCanvas?) {
            layer |> draw_rect(float4(20.0,20.0,8.0,16.0),draw)
            draw |> set_color(0xff0000ffu)
            layer |> draw_rect(float4(28.0,20.0,8.0,16.0),draw)
            return skia_ok()
        } |> skia_try
        let mixed=graph_pixel(surface,27,25)
        check_graph((mixed>>24)==255u && ((mixed>>16)&255u)>=126u && ((mixed>>16)&255u)<=129u && (mixed&255u)>=126u && (mixed&255u)<=129u && Skia_SaveCount(c)==count,
            "group kernel sees neighboring draws and restores layer") |> skia_try
        return skia_ok()
    }
}
def test_sources_merge_transform() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,64))) |> skia_use
        let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
        var pixels <- array(0xffff0000u,0xff00ff00u,0xff0000ffu,0xffffffffu)
        source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
        let image : SkImage? = source |> with_snapshot() |> skia_use
        let image_filter : SkImageFilter? = image_source_filter(image,float4(8.0,8.0,32.0,32.0)) |> with_image_filter() |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xff00ff00u,antialias=false)) |> skia_use
        let c=canvas(surface)
        paint |> set_image_filter(image_filter)
        c |> clear(0u)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,12,12)==0xffff0000u && graph_pixel(surface,36,12)==0xff00ff00u && graph_pixel(surface,12,36)==0xff0000ffu && graph_pixel(surface,36,36)==0xffffffffu,"image source scale and sampling") |> skia_try
        let picture : SkPicture? = record_picture(PictureOptions(bounds=float4(0.0,0.0,64.0,64.0))) $(record : SkCanvas?) {
            return with_paint(PaintOptions(color=0xffff0000u,antialias=false)) $(p : SkPaint?) {
                record |> draw_rect(float4(5.0,5.0,30.0,30.0),p)
                return skia_ok()
            }
        } |> with_picture() |> skia_use
        let picture_filter : SkImageFilter? = picture_source_filter(picture,float4(10.0,10.0,10.0,10.0)) |> with_image_filter() |> skia_use
        paint |> set_image_filter(picture_filter)
        c |> clear(0u)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,15,15)==0xffff0000u && graph_pixel(surface,6,6)==0u && graph_pixel(surface,25,25)==0u,"picture source target is a real clip") |> skia_try
        let shader : SkShader? = solid_shader(0xff00ff00u) |> with_shader() |> skia_use
        let shader_filter : SkImageFilter? = shader_source_filter(shader,true) |> with_image_filter() |> skia_use
        let cropped : SkImageFilter? = crop_filter(float4(2.0,4.0,8.0,8.0),shader_filter) |> with_image_filter() |> skia_use
        let transformed : SkImageFilter? = matrix_transform_filter(multiply(matrix_translation(float2(10.0,0.0)),matrix_scale(float2(2.0))),cropped) |> with_image_filter() |> skia_use
        paint |> set_image_filter(transformed)
        c |> clear(0u)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,15,10)==0xff00ff00u && graph_pixel(surface,5,10)==0u && graph_pixel(surface,35,10)==0u,"shader source and local matrix transform") |> skia_try
        let red : SkShader? = solid_shader(0x80ff0000u) |> with_shader() |> skia_use
        let blue : SkShader? = solid_shader(0x800000ffu) |> with_shader() |> skia_use
        let red_filter : SkImageFilter? = shader_source_filter(red) |> with_image_filter() |> skia_use
        let blue_filter : SkImageFilter? = shader_source_filter(blue) |> with_image_filter() |> skia_use
        var inputs : array<SkImageFilter const?>
        push(inputs,red_filter)
        push(inputs,blue_filter)
        let merged : SkImageFilter? = merge_filters(inputs) |> with_image_filter() |> skia_use
        paint |> set_image_filter(merged)
        clear(inputs)
        c |> clear(0u)
        c |> draw_paint(paint)
        let merged_pixel=graph_pixel(surface,10,10)
        check_graph((merged_pixel>>24)>=191u && (merged_pixel>>24)<=193u && (merged_pixel&255u)>((merged_pixel>>16)&255u),"merge uses ordered SrcOver and owns copied refs") |> skia_try
        let empty_merge : SkImageFilter? = merge_filters(inputs) |> with_image_filter() |> skia_use
        paint |> set_image_filter(empty_merge)
        c |> clear(0u)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,10,10)==0u,"empty merge is transparent, not source graphic") |> skia_try
        var implicit_source : SkImageFilter const?
        push(inputs,implicit_source)
        let source_merge : SkImageFilter? = merge_filters(inputs) |> with_image_filter() |> skia_use
        paint |> set_image_filter(source_merge)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,10,10)==0xff00ff00u,"null merge input means source graphic") |> skia_try
        var no_image : SkImage?
        var no_picture : SkPicture?
        var no_shader : SkShader?
        let empty_image : SkImageFilter? = image_source_filter(no_image) |> with_image_filter() |> skia_use
        let empty_picture : SkImageFilter? = picture_source_filter(no_picture) |> with_image_filter() |> skia_use
        let empty_shader : SkImageFilter? = shader_source_filter(no_shader) |> with_image_filter() |> skia_use
        clear(inputs)
        push(inputs,empty_image); push(inputs,empty_picture); push(inputs,empty_shader)
        let empty_sources : SkImageFilter? = merge_filters(inputs) |> with_image_filter() |> skia_use
        paint |> set_image_filter(empty_sources)
        c |> clear(0u)
        c |> draw_paint(paint)
        check_graph(graph_pixel(surface,10,10)==0u,"null leaf sources produce transparent filters") |> skia_try
        var invalid_matrix <- matrix_transform_filter(matrix_scale(float2(0.0,1.0)))
        var invalid_rect <- image_source_filter(image,float4(0.0,0.0,-1.0,1.0),float4(0.0,0.0,4.0,4.0))
        var invalid_sampling <- image_source_filter(image,SamplingOptions(cubic=true,b=-1.0))
        check_graph(is_err(invalid_matrix) && is_err(invalid_rect) && is_err(invalid_sampling),"matrix/rectangle/sampling validation") |> skia_try
        return skia_ok()
    }
}
def make_graph_fixture() {
    return record_picture(PictureOptions(bounds=float4(0.0,0.0,32.0,32.0))) $(record : SkCanvas?) {
        return skia_scope() {
            let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,1))) |> skia_use
            var pixels <- array(0xffff0000u,0xff0000ffu)
            source |> write_pixels(int4(0,0,2,1),pixels) |> skia_try
            let image : SkImage? = source |> with_snapshot() |> skia_use
            let first : SkImageFilter? = image_source_filter(image,float4(0.0,0.0,32.0,32.0)) |> with_image_filter() |> skia_use
            let picture : SkPicture? = record_picture(PictureOptions(bounds=float4(0.0,0.0,32.0,32.0))) $(c : SkCanvas?) {
                return with_paint(PaintOptions(color=0xff00ff00u,antialias=false)) $(p : SkPaint?) {
                    c |> draw_rect(float4(0.0,0.0,16.0,32.0),p)
                    p |> set_color(0xffffff00u)
                    c |> draw_rect(float4(16.0,0.0,16.0,32.0),p)
                    return skia_ok()
                }
            } |> with_picture() |> skia_use
            let second : SkImageFilter? = picture_source_filter(picture) |> with_image_filter() |> skia_use
            let effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader a; uniform shader b; uniform float amount; half4 main(float2 p) \{ return mix(a.eval(p),b.eval(p),amount); \}") |> with_runtime_effect() |> skia_use
            let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
            builder |> set_uniform("amount",0.25) |> skia_try
            var names <- array("a","b")
            var inputs : array<SkImageFilter const?>
            push(inputs,first); push(inputs,second)
            let mix : SkImageFilter? = runtime_image_filter(builder,names,inputs) |> with_image_filter() |> skia_use
            builder |> set_uniform("amount",0.75) |> skia_try
            clear(names); clear(inputs)
            let paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
            paint |> set_image_filter(mix)
            record |> draw_paint(paint)
            return skia_ok()
        }
    }
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
def test_multi_and_serialization() : SkiaStatus {
    return skia_scope() {
        let picture : SkPicture? = make_graph_fixture() |> with_picture() |> skia_use
        verify_graph_fixture(picture) |> skia_try
        var bytes=serialize_picture(picture) |> skia_try
        let decoded : SkPicture? = picture_from_bytes(bytes) |> with_picture() |> skia_use
        clear(bytes)
        verify_graph_fixture(decoded) |> skia_try
        decoded |> save_picture("filter-graph-roundtrip.skp") |> skia_try
        let effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader a; uniform shader b; half4 main(float2 p) \{ return 0.5*(a.eval(p)+b.eval(p)); \}") |> with_runtime_effect() |> skia_use
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        var names <- array("a","a")
        var inputs : array<SkImageFilter const?>
        var source : SkImageFilter const?
        push(inputs,source); push(inputs,source)
        var duplicate <- runtime_image_filter(builder,names,inputs)
        names[1]="missing"
        var missing <- runtime_image_filter(builder,names,inputs)
        pop(inputs)
        var mismatch <- runtime_image_filter(builder,names,inputs)
        var ambiguous <- runtime_image_filter(builder)
        check_graph(is_err(duplicate) && is_err(missing) && is_err(mismatch) && is_err(ambiguous),"invalid multi-input names, counts and automatic binding") |> skia_try
        let cf : SkRuntimeEffect? = compile_runtime_color_filter("half4 main(half4 c) \{ return c; \}") |> with_runtime_effect() |> skia_use
        let cf_builder : SkRuntimeEffectBuilder? = cf |> with_runtime_builder() |> skia_use
        clear(names); clear(inputs)
        var wrong_stage <- runtime_image_filter(cf_builder,names,inputs)
        check_graph(is_err(wrong_stage),"non-shader builder rejected before construction") |> skia_try
        let procedural : SkRuntimeEffect? = compile_runtime_shader("half4 main(float2 p) \{ return half4(0,0,1,1); \}") |> with_runtime_effect() |> skia_use
        let procedural_builder : SkRuntimeEffectBuilder? = procedural |> with_runtime_builder() |> skia_use
        let leaf : SkImageFilter? = runtime_image_filter(procedural_builder,names,inputs) |> with_image_filter() |> skia_use
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(8,8))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
        paint |> set_image_filter(leaf)
        canvas(surface) |> draw_paint(paint)
        check_graph(graph_pixel(surface,4,4)==0xff0000ffu,"explicit zero-input runtime graph leaf") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    for (result in fixed_array(test_single_and_radius(),test_group_layer(),test_sources_merge_transform(),test_multi_and_serialization())) {
        if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    }
    print("PASS filter graph: runtime inputs, radius, layers, sources, merge, transform, snapshots, SKP\n")
    return 0
}
