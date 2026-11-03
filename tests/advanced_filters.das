options gen2
require dasskia/skia_advanced_filters
require dasskia/skia_scope
require math

def check_advanced(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("advanced_filters_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def adv_pixel(surface : SkSurface?; x,y : int) : uint {
    var color : uint
    Skia_ReadPixel(surface,x,y,color)
    return color
}
def test_convolution() : SkiaStatus {
    return skia_scope() {
        let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(5,1))) |> skia_use
        var pixels <- array(0xff000000u,0xff000000u,0xffffffffu,0xff000000u,0xff000000u)
        source |> write_pixels(int4(0,0,5,1),pixels) |> skia_try
        let image : SkImage? = source |> with_snapshot() |> skia_use
        let input : SkImageFilter? = image_source_filter(image) |> with_image_filter() |> skia_use
        let target : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(8,8))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(antialias=false)) |> skia_use
        let c=canvas(target)
        var weights <- array(1.0,1.0,1.0)
        var settings=ConvolutionOptions(size=int2(3,1),offset=int2(1,0),gain=1.0/3.0,
            crop=FilterCrop(enabled=true,rect=float4(0.0,0.0,5.0,1.0)),tile=SkTileMode.Clamp)
        let average : SkImageFilter? = convolution_filter(weights,settings,input) |> with_image_filter() |> skia_use
        weights[0]=0.0;weights[1]=0.0;weights[2]=0.0
        paint |> set_image_filter(average)
        c |> clear(0u);c |> draw_paint(paint)
        check_advanced((adv_pixel(target,1,0)&255u)>=83u && (adv_pixel(target,1,0)&255u)<=87u &&
            (adv_pixel(target,2,0)&255u)>=83u && (adv_pixel(target,3,0)&255u)>=83u && adv_pixel(target,0,0)==0xff000000u,
            "convolution averages neighbors and copies kernel") |> skia_try
        var one <- array(0.0)
        let biased : SkImageFilter? = convolution_filter(one,ConvolutionOptions(size=int2(1,1),offset=int2(0,0),bias=64.0),input) |> with_image_filter() |> skia_use
        paint |> set_image_filter(biased)
        c |> clear(0u);c |> draw_paint(paint)
        check_advanced((adv_pixel(target,2,0)&255u)>=63u && (adv_pixel(target,2,0)&255u)<=65u,"convolution bias uses 0..255 units") |> skia_try
        pixels[0]=0xffffffffu;pixels[1]=0xffffffffu;pixels[3]=0xffffffffu;pixels[4]=0xffffffffu
        source |> write_pixels(int4(0,0,5,1),pixels) |> skia_try
        let white_image : SkImage? = source |> with_snapshot() |> skia_use
        let white : SkImageFilter? = image_source_filter(white_image) |> with_image_filter() |> skia_use
        weights[0]=1.0;weights[1]=1.0;weights[2]=1.0
        let clamped : SkImageFilter? = convolution_filter(weights,settings,white) |> with_image_filter() |> skia_use
        settings.tile=SkTileMode.Decal
        let decal : SkImageFilter? = convolution_filter(weights,settings,white) |> with_image_filter() |> skia_use
        paint |> set_image_filter(clamped);c |> clear(0u);c |> draw_paint(paint)
        let edge_clamp=adv_pixel(target,0,0)&255u
        paint |> set_image_filter(decal);c |> clear(0u);c |> draw_paint(paint)
        let edge_decal=adv_pixel(target,0,0)&255u
        check_advanced(edge_clamp>250u && edge_decal>=168u && edge_decal<=172u,"native convolution crop controls edge tiling") |> skia_try
        pixels[0]=0u;pixels[1]=0u;pixels[2]=0xffffffffu;pixels[3]=0u;pixels[4]=0u
        source |> write_pixels(int4(0,0,5,1),pixels) |> skia_try
        let alpha_image : SkImage? = source |> with_snapshot() |> skia_use
        let alpha_source : SkImageFilter? = image_source_filter(alpha_image) |> with_image_filter() |> skia_use
        settings.convolve_alpha=true
        let alpha : SkImageFilter? = convolution_filter(weights,settings,alpha_source) |> with_image_filter() |> skia_use
        paint |> set_image_filter(alpha);c |> clear(0u);c |> draw_paint(paint)
        check_advanced((adv_pixel(target,1,0)>>24)>=83u && (adv_pixel(target,1,0)>>24)<=87u && (adv_pixel(target,2,0)>>24)>=83u,"convolve alpha spreads coverage") |> skia_try
        var bad_size <- convolution_filter(weights,ConvolutionOptions(size=int2(2147483647,2147483647)))
        var bad_offset <- convolution_filter(weights,ConvolutionOptions(size=int2(3,1),offset=int2(3,0)))
        var huge : array<float>;resize(huge,257)
        var native_limit <- convolution_filter(huge,ConvolutionOptions(size=int2(257,1),offset=int2(0,0)))
        check_advanced(is_err(bad_size) && is_err(bad_offset) && is_err(native_limit),"kernel area/count, offset and native size limit") |> skia_try
        return skia_ok()
    }
}
def test_spatial() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,64))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        let c=canvas(surface)
        let map : SkShader? = solid_shader(0xffff8000u) |> with_shader() |> skia_use
        let map_filter : SkImageFilter? = shader_source_filter(map) |> with_image_filter() |> skia_use
        let displacement : SkImageFilter? = displacement_filter(SkColorChannel.R,SkColorChannel.G,8.0,map_filter,null) |> with_image_filter() |> skia_use
        paint |> set_image_filter(displacement);c |> clear(0u)
        c |> draw_rect(float4(20.0,20.0,8.0,8.0),paint)
        check_advanced(adv_pixel(surface,17,24)==0xffff0000u && adv_pixel(surface,27,24)==0u,"displacement centered at 0.5 with selected RG channels") |> skia_try
        let shadow : SkImageFilter? = shadow_only_filter(float2(20.0,0.0),float2(0.0),0xff0000ffu) |> with_image_filter() |> skia_use
        paint |> set_image_filter(shadow);c |> clear(0u)
        c |> draw_rect(float4(10.0,10.0,10.0,10.0),paint)
        check_advanced(adv_pixel(surface,15,15)==0u && adv_pixel(surface,35,15)==0xff0000ffu,"shadow-only excludes source") |> skia_try
        let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,1))) |> skia_use
        var pixels <- array(0xffff0000u,0xff0000ffu)
        source |> write_pixels(int4(0,0,2,1),pixels) |> skia_try
        let image : SkImage? = source |> with_snapshot() |> skia_use
        let input : SkImageFilter? = image_source_filter(image) |> with_image_filter() |> skia_use
        let tiled : SkImageFilter? = tile_filter(float4(0.0,0.0,2.0,1.0),float4(4.0,4.0,8.0,4.0),input) |> with_image_filter() |> skia_use
        paint |> set_image_filter(tiled);c |> clear(0u);c |> draw_paint(paint)
        check_advanced(adv_pixel(surface,4,5)==0xffff0000u && adv_pixel(surface,5,5)==0xff0000ffu && adv_pixel(surface,6,5)==0xffff0000u && adv_pixel(surface,3,5)==0u,"tile repeats and crops destination") |> skia_try
        let stripe_surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(8,8))) |> skia_use
        var stripe : array<uint>;resize(stripe,64)
        for (i in range(64)) { stripe[i]=i%8==3?0xffff0000u:0xff0000ffu }
        stripe_surface |> write_pixels(int4(0,0,8,8),stripe) |> skia_try
        let stripe_image : SkImage? = stripe_surface |> with_snapshot() |> skia_use
        let stripe_filter : SkImageFilter? = image_source_filter(stripe_image) |> with_image_filter() |> skia_use
        let magnified : SkImageFilter? = magnifier_filter(float4(0.0,0.0,8.0,8.0),MagnifierOptions(zoom=2.0),stripe_filter) |> with_image_filter() |> skia_use
        paint |> set_image_filter(magnified);c |> clear(0u);c |> draw_paint(paint)
        check_advanced(adv_pixel(surface,2,4)==0xffff0000u && adv_pixel(surface,1,4)==0xff0000ffu,"magnifier zooms around lens center") |> skia_try
        var identity_called=false
        magnifier_filter(float4(0.0,0.0,8.0,8.0),MagnifierOptions(zoom=1.0)) |> with_image_filter() $(identity : SkImageFilter?) {
            identity_called=true
            check_advanced(identity==null,"magnifier no-op is valid null") |> skia_try
            return skia_ok()
        } |> skia_try
        check_advanced(identity_called,"valid null still enters scope") |> skia_try
        var bad_zoom <- magnifier_filter(float4(0.0,0.0,8.0,8.0),MagnifierOptions(zoom=0.0))
        var bad_scale <- displacement_filter(SkColorChannel.R,SkColorChannel.G,sqrt(-1.0),null,null)
        check_advanced(is_err(bad_zoom) && is_err(bad_scale),"spatial parameter rejection") |> skia_try
        return skia_ok()
    }
}
def test_blending() : SkiaStatus {
    return skia_scope() {
        let red : SkShader? = solid_shader(0xffff0000u) |> with_shader() |> skia_use
        let blue : SkShader? = solid_shader(0xff0000ffu) |> with_shader() |> skia_use
        let bg : SkImageFilter? = shader_source_filter(red) |> with_image_filter() |> skia_use
        let fg : SkImageFilter? = shader_source_filter(blue) |> with_image_filter() |> skia_use
        let arithmetic : SkImageFilter? = arithmetic_filter(float4(0.0,0.25,0.75,0.0),bg,fg) |> with_image_filter() |> skia_use
        let target : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(8,8))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
        let c=canvas(target)
        paint |> set_image_filter(arithmetic);c |> clear(0u);c |> draw_paint(paint)
        let mixed=adv_pixel(target,4,4)
        check_advanced(((mixed>>16)&255u)>=190u && ((mixed>>16)&255u)<=192u && (mixed&255u)>=63u && (mixed&255u)<=65u,"arithmetic foreground/background coefficient order") |> skia_try
        arithmetic_filter(float4(0.0,1.0,0.0,0.0),null,null) |> with_image_filter() $(identity : SkImageFilter?) {
            check_advanced(identity==null,"arithmetic source optimization is valid null") |> skia_try
            return skia_ok()
        } |> skia_try
        let source_mode : SkBlender? = mode_blender(SkBlendMode.Src) |> with_blender() |> skia_use
        blend_image_filter(source_mode,bg,null) |> with_image_filter() $(identity : SkImageFilter?) {
            check_advanced(identity==null,"custom blend source mode accepts null source") |> skia_try
            return skia_ok()
        } |> skia_try
        let effect : SkRuntimeEffect? = compile_runtime_blender("half4 main(half4 s,half4 d) \{ return 0.5*(s+d); \}") |> with_runtime_effect() |> skia_use
        let builder : SkRuntimeEffectBuilder? = effect |> with_runtime_builder() |> skia_use
        let blender : SkBlender? = runtime_blender(builder) |> with_blender() |> skia_use
        let custom : SkImageFilter? = blend_image_filter(blender,bg,fg) |> with_image_filter() |> skia_use
        paint |> set_image_filter(custom);c |> clear(0u);c |> draw_paint(paint)
        check_advanced(((adv_pixel(target,4,4)>>16)&255u)>=127u && (adv_pixel(target,4,4)&255u)>=127u,"runtime blender in image-filter graph") |> skia_try
        let empty : SkImageFilter? = empty_filter() |> with_image_filter() |> skia_use
        paint |> set_image_filter(empty);c |> clear(0u);c |> draw_paint(paint)
        check_advanced(adv_pixel(target,4,4)==0u,"empty filter is transparent") |> skia_try
        return skia_ok()
    }
}
def lighting_case(index : int) {
    var settings=LightingOptions(surface_scale=0.0,coefficient=index<3?0.5:0.25,shininess=8.0,
        crop=FilterCrop(enabled=true,rect=float4(16.0,16.0,16.0,16.0)))
    if (index==0) { return <- distant_diffuse_filter(float3(0.0,0.0,1.0),settings) }
    if (index==1) { return <- point_diffuse_filter(float3(24.5,24.5,100.0),settings) }
    if (index==2) { return <- spot_diffuse_filter(float3(24.5,24.5,100.0),float3(24.5,24.5,0.0),settings) }
    if (index==3) { return <- distant_specular_filter(float3(0.0,0.0,1.0),settings) }
    if (index==4) { return <- point_specular_filter(float3(24.5,24.5,100.0),settings) }
    return <- spot_specular_filter(float3(24.5,24.5,100.0),float3(24.5,24.5,0.0),settings)
}
def test_lighting() : SkiaStatus {
    return skia_scope() {
        let target : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(48,48))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffffffffu)) |> skia_use
        let c=canvas(target)
        for (i in range(6)) {
            lighting_case(i) |> with_image_filter() $(filter : SkImageFilter?) {
                paint |> set_image_filter(filter);c |> clear(0u);c |> draw_paint(paint)
                let pixel=adv_pixel(target,24,24)
                if (i<3) {
                    check_advanced((pixel>>24)==255u && (pixel&255u)>=125u && (pixel&255u)<=130u,"diffuse light on flat surface") |> skia_try
                } else {
                    check_advanced((pixel>>24)>=62u && (pixel>>24)<=66u && (pixel&255u)>250u,"specular intensity stored as premultiplied alpha") |> skia_try
                }
                check_advanced(adv_pixel(target,4,4)==0u,"lighting crop bounds output") |> skia_try
                return skia_ok()
            } |> skia_try
        }
        var invalid <- distant_diffuse_filter(float3(0.0,0.0,1.0),LightingOptions(coefficient=-1.0))
        check_advanced(is_err(invalid),"negative lighting coefficient rejected") |> skia_try
        return skia_ok()
    }
}
def make_advanced_fixture() {
    return record_picture(PictureOptions(bounds=float4(0.0,0.0,64.0,32.0))) $(record : SkCanvas?) {
        return skia_scope() {
            let red : SkShader? = solid_shader(0xffff0000u) |> with_shader() |> skia_use
            let source : SkImageFilter? = shader_source_filter(red) |> with_image_filter() |> skia_use
            var weights <- array(1.0)
            let convolution : SkImageFilter? = convolution_filter(weights,ConvolutionOptions(size=int2(1,1),offset=int2(0,0),gain=0.5),source) |> with_image_filter() |> skia_use
            let paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
            paint |> set_image_filter(convolution)
            record |> with_saved() $(saved : SkCanvas?) {
                saved |> clip_rect(float4(0.0,0.0,32.0,32.0))
                saved |> draw_paint(paint)
                return skia_ok()
            } |> skia_try
            let light : SkImageFilter? = distant_diffuse_filter(float3(0.0,0.0,1.0),LightingOptions(surface_scale=0.0,coefficient=0.5,
                crop=FilterCrop(enabled=true,rect=float4(32.0,0.0,32.0,32.0)))) |> with_image_filter() |> skia_use
            paint |> set_image_filter(light)
            record |> draw_paint(paint)
            return skia_ok()
        }
    }
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
def test_advanced_serialization() : SkiaStatus {
    return skia_scope() {
        let picture : SkPicture? = make_advanced_fixture() |> with_picture() |> skia_use
        verify_advanced_fixture(picture) |> skia_try
        var bytes=serialize_picture(picture) |> skia_try
        let decoded : SkPicture? = picture_from_bytes(bytes) |> with_picture() |> skia_use
        clear(bytes)
        verify_advanced_fixture(decoded) |> skia_try
        decoded |> save_picture("advanced-filters-roundtrip.skp") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    for (result in fixed_array(test_convolution(),test_spatial(),test_blending(),test_lighting(),test_advanced_serialization())) {
        if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    }
    print("PASS advanced filters: convolution, displacement, tile, magnifier, arithmetic, blender, shadow, lighting, SKP\n")
    return 0
}
