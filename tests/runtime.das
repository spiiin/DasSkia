options gen2
require dasskia/skia_runtime
require dasskia/skia_picture
require dasskia/skia_scope
require math

def check_runtime(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("runtime_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def pixel(surface : SkSurface?; x,y : int) : uint {
    var out : uint
    Skia_ReadPixel(surface,x,y,out)
    return out
}
def test_uniforms() : SkiaStatus {
    var invalid <- compile_runtime_shader("half4 main(float2 p) \{ return missing; \}")
    check_runtime(is_err(invalid) && length(unwrap_err(invalid).message)>5,"compiler diagnostic") |> skia_try
    return skia_scope() {
        let source="layout(color) uniform half4 tint; uniform float2 size; uniform float phase; uniform int channel; uniform float weights[2]; uniform float3x3 transform; half4 main(float2 p) \{ float3 q=transform*float3(p,1); float v=step(size.x,q.x)*weights[0]+weights[1]+phase; return half4(tint.rgb*(channel==1?v:1),tint.a); \}"
        let effect : SkRuntimeEffect? = compile_runtime_shader(source) |> with_runtime_effect() |> skia_use
        check_runtime(runtime_source(effect)==source && runtime_supports(effect,SkiaRuntimeKind.Shader),"source and allowed stage") |> skia_try
        let info=unwrap(find_uniform(effect,"tint"))
        let weights_info=unwrap(find_uniform(effect,"weights"))
        check_runtime(info.kind==SkRuntimeUniformType.Float4 && (info.flags&2u)!=0u && info.bytes==16ul &&
            weights_info.count==2 && (weights_info.flags&1u)!=0u && weights_info.bytes==8ul &&
            info.offset+info.bytes<=runtime_uniform_size(effect),"uniform reflection layout and color/array flags") |> skia_try
        check_runtime(is_none(uniform_info(effect,-1)) && is_none(uniform_info(effect,runtime_uniform_count(effect))) &&
            is_none(find_uniform(effect,"absent")) && is_none(child_info(effect,0)),"reflection bounds and missing names") |> skia_try
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        builder |> set_uniform("tint",float4(1.0,0.0,0.0,1.0)) |> skia_try
        builder |> set_uniform("size",float2(10.0,20.0)) |> skia_try
        builder |> set_uniform("phase",0.0) |> skia_try
        builder |> set_uniform("channel",1) |> skia_try
        var weights <- array(0.5,0.25)
        builder |> set_uniform("weights",weights) |> skia_try
        weights[0]=0.0
        builder |> set_uniform("transform",matrix_translation(float2(3.0,0.0))) |> skia_try
        check_runtime(is_err(set_uniform(builder,"channel",1.0)) && is_err(set_uniform(builder,"tint",float3(1.0))) &&
            is_err(set_uniform(builder,"absent",1.0)) && is_err(set_uniform(builder,"weights",float2(1.0))),"uniform type checks") |> skia_try
        var wrong_size <- array(0.2)
        var wrong_ints <- array(1,2)
        check_runtime(is_err(set_uniform(builder,"weights",wrong_size)) && is_err(set_uniform(builder,"weights",wrong_ints)),"array size and numeric type checks") |> skia_try
        let first : SkShader? = runtime_shader(builder) |> with_shader() |> skia_use
        builder |> set_uniform("phase",0.25) |> skia_try
        let second : SkShader? = runtime_shader(builder) |> with_shader() |> skia_use
        var wrong_stage <- runtime_color_filter(builder)
        var wrong_blender <- runtime_blender(builder)
        check_runtime(is_err(wrong_stage) && is_err(wrong_blender),"wrong output stage rejected") |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(24,12))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(antialias=false)) |> skia_use
        paint |> set_shader(first)
        let c=canvas(surface)
        c |> clear(0u)
        c |> draw_rect(float4(0.0,0.0,24.0,6.0),paint)
        paint |> set_shader(second)
        c |> draw_rect(float4(0.0,6.0,24.0,6.0),paint)
        let a=(pixel(surface,6,2)>>16)&255u
        let b=(pixel(surface,7,2)>>16)&255u
        let changed=(pixel(surface,6,8)>>16)&255u
        check_runtime(a>=63u && a<=65u && b>=190u && b<=192u && changed>=127u && changed<=129u,
            "matrix convention, copied arrays and immutable uniform snapshots") |> skia_try
        let translated : SkShader? = runtime_shader(builder,matrix_translation(float2(4.0,0.0))) |> with_shader() |> skia_use
        paint |> set_shader(translated)
        c |> draw_paint(paint)
        check_runtime(((pixel(surface,7,2)>>16)&255u)<140u,"shader local matrix") |> skia_try
        return skia_ok()
    }
}
def configure_children(paint : SkPaint?) : SkiaStatus {
    return skia_scope() {
        let effect : SkRuntimeEffect? = compile_runtime_shader("uniform shader source; uniform colorFilter tint; uniform blender blend; half4 main(float2 p) \{ return blend.eval(tint.eval(source.eval(p)),half4(0,0,1,1)); \}") |> with_runtime_effect() |> skia_use
        check_runtime(runtime_child_count(effect)==3 && unwrap(find_child(effect,"source")).kind==SkRuntimeChildType.Shader &&
            unwrap(find_child(effect,"tint")).kind==SkRuntimeChildType.ColorFilter && unwrap(find_child(effect,"blend")).kind==SkRuntimeChildType.Blender &&
            is_none(child_info(effect,3)) && is_none(find_child(effect,"missing")),"child reflection") |> skia_try
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        let red : SkShader? = solid_shader(0xffff0000u) |> with_shader() |> skia_use
        let filter : SkColorFilter? = blend_color_filter(0xff808080u,SkBlendMode.Modulate) |> with_color_filter() |> skia_use
        let blend : SkBlender? = mode_blender(SkBlendMode.Src) |> with_blender() |> skia_use
        builder |> set_child("source",red) |> skia_try
        builder |> set_child("tint",filter) |> skia_try
        builder |> set_child("blend",blend) |> skia_try
        check_runtime(is_err(set_child(builder,"source",filter)) && is_err(set_child(builder,"missing",red)),"child name/type mismatch rejected") |> skia_try
        let shader : SkShader? = runtime_shader(builder) |> with_shader() |> skia_use
        paint |> set_shader(shader)
        // Mutating the builder must not mutate already-created child snapshots.
        let blue : SkShader? = solid_shader(0xff0000ffu) |> with_shader() |> skia_use
        builder |> set_child("source",blue) |> skia_try
        return skia_ok()
    }
}
def test_children_and_serialization() : SkiaStatus {
    return skia_scope() {
        let paint : SkPaint? = with_paint(PaintOptions(antialias=false)) |> skia_use
        configure_children(paint) |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(16,16))) |> skia_use
        let c=canvas(surface)
        c |> clear(0u)
        c |> draw_paint(paint)
        let color=pixel(surface,5,5)
        check_runtime(((color>>16)&255u)>=127u && ((color>>16)&255u)<=129u && (color&255u)==0u,"child retention and snapshot after releasing builder/effect") |> skia_try
        let picture : SkPicture? = record_picture(PictureOptions(bounds=float4(0.0,0.0,16.0,16.0))) $(record : SkCanvas?) {
            record |> draw_paint(paint)
            return skia_ok()
        } |> with_picture() |> skia_use
        var bytes=serialize_picture(picture) |> skia_try
        let decoded : SkPicture? = picture_from_bytes(bytes) |> with_picture() |> skia_use
        clear(bytes)
        paint |> reset_paint()
        c |> clear(0u)
        c |> draw_picture(decoded)
        check_runtime(pixel(surface,5,5)==color,"runtime shader SKP roundtrip") |> skia_try
        return skia_ok()
    }
}
def test_filter_and_blender() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(16,16))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        compile_runtime_color_filter("uniform float gain; half4 main(half4 c) \{ return half4(c.bgr*gain,c.a); \}") |> with_runtime_effect() $(effect : SkRuntimeEffect?) {
            return effect |> with_runtime_builder() $(builder : SkRuntimeEffectBuilder?) {
                builder |> set_uniform("gain",0.5) |> skia_try
                runtime_color_filter(builder) |> with_color_filter() $(filter : SkColorFilter?) {
                    paint |> set_color_filter(filter)
                    return skia_ok()
                } |> skia_try
                builder |> set_uniform("gain",1.0) |> skia_try
                return skia_ok()
            }
        } |> skia_try
        let c=canvas(surface)
        c |> clear(0u)
        c |> draw_paint(paint)
        check_runtime((pixel(surface,5,5)&255u)>=127u && (pixel(surface,5,5)&255u)<=129u && ((pixel(surface,5,5)>>16)&255u)==0u,"runtime color filter") |> skia_try
        paint |> set_color_filter()
        compile_runtime_blender("uniform float ratio; half4 main(half4 s,half4 d) \{ return mix(d,s,ratio); \}") |> with_runtime_effect() $(effect : SkRuntimeEffect?) {
            return effect |> with_runtime_builder() $(builder : SkRuntimeEffectBuilder?) {
                builder |> set_uniform("ratio",0.25) |> skia_try
                runtime_blender(builder) |> with_blender() $(blend : SkBlender?) {
                    paint |> set_blender(blend)
                    return skia_ok()
                } |> skia_try
                return skia_ok()
            }
        } |> skia_try
        check_runtime(is_none(paint_blend_mode_option(paint)),"custom blender has no enum blend mode") |> skia_try
        c |> clear(0xff0000ffu)
        c |> draw_paint(paint)
        let mixed=pixel(surface,5,5)
        check_runtime(((mixed>>16)&255u)>=63u && ((mixed>>16)&255u)<=65u && (mixed&255u)>=190u && (mixed&255u)<=192u,"runtime source/destination blender") |> skia_try
        paint |> set_blender()
        check_runtime(unwrap(paint_blend_mode_option(paint))==SkBlendMode.SrcOver,"null blender restores SrcOver") |> skia_try
        paint |> set_blend_mode(SkBlendMode.Multiply)
        check_runtime(unwrap(paint_blend_mode_option(paint))==SkBlendMode.Multiply,"enum blend mode remains available") |> skia_try
        return skia_ok()
    }
}
def test_numeric_shapes() : SkiaStatus {
    return skia_scope() {
        let effect : SkRuntimeEffect? = compile_runtime_shader("uniform float a; uniform float2 b; uniform float3 c; uniform float4 d; uniform int i; uniform int2 j; uniform int3 k; uniform int4 l; uniform float2x2 m2; uniform float4x4 m4; half4 main(float2 p) \{ return half4(a+b.x+c.x+d.x+float(i+j.x+k.x+l.x)+m2[0][0]+m4[0][0],0,0,1); \}",RuntimeOptions(unoptimized=true)) |> with_runtime_effect() |> skia_use
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        builder |> set_uniform("a",0.1) |> skia_try
        builder |> set_uniform("b",float2(0.1,0.0)) |> skia_try
        builder |> set_uniform("c",float3(0.1,0.0,0.0)) |> skia_try
        builder |> set_uniform("d",float4(0.1,0.0,0.0,0.0)) |> skia_try
        builder |> set_uniform("i",0) |> skia_try
        builder |> set_uniform("j",int2(0)) |> skia_try
        builder |> set_uniform("k",int3(0)) |> skia_try
        builder |> set_uniform("l",int4(0)) |> skia_try
        var ints <- array(0,0,0,0)
        builder |> set_uniform("l",ints) |> skia_try
        var matrix2 <- array(0.1,0.0,0.0,1.0)
        var matrix4 <- array(0.1,0.0,0.0,0.0, 0.0,1.0,0.0,0.0, 0.0,0.0,1.0,0.0, 0.0,0.0,0.0,1.0)
        builder |> set_uniform("m2",matrix2) |> skia_try
        builder |> set_uniform("m4",matrix4) |> skia_try
        let shader : SkShader? = runtime_shader(builder) |> with_shader() |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
        paint |> set_shader(shader)
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(4,4))) |> skia_use
        canvas(surface) |> draw_paint(paint)
        check_runtime(((pixel(surface,1,1)>>16)&255u)>=151u && ((pixel(surface,1,1)>>16)&255u)<=155u,"scalar/vector/int/matrix setters") |> skia_try
        var called=false
        let failure=compile_runtime_shader("bad") |> with_runtime_effect() $(owned : SkRuntimeEffect?) { called=true; return skia_ok() }
        check_runtime(is_err(failure) && !called,"compiler Err skips scope") |> skia_try
        let body_error=effect |> with_runtime_builder() $(owned : SkRuntimeEffectBuilder?) { return err(skia_error("body","expected"),type<SkiaUnit>) }
        check_runtime(is_err(body_error) && unwrap_err(body_error).operation=="body","builder scope preserves Err") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    for (result in fixed_array(test_uniforms(),test_children_and_serialization(),test_filter_and_blender(),test_numeric_shapes())) {
        if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    }
    print("PASS runtime: SkSL compile, reflection, uniforms, matrices, children, snapshots, filters, blenders, SKP\n")
    return 0
}
