options gen2
module skia_advanced_filters shared public
require dasskia/skia_filter_graph public

struct FilterCrop {
    enabled : bool = false
    rect : float4
}
struct ConvolutionOptions {
    size : int2 = int2(3,3)
    offset : int2 = int2(1,1)
    gain : float = 1.0
    bias : float = 0.0
    tile : SkTileMode = SkTileMode.Decal
    convolve_alpha : bool = false
    crop : FilterCrop = FilterCrop()
}
struct MagnifierOptions {
    zoom : float = 2.0
    inset : float = 0.0
    sampling : SamplingOptions = SamplingOptions()
    crop : FilterCrop = FilterCrop()
}
struct LightingOptions {
    color : uint = 0xffffffffu
    surface_scale : float = 1.0
    coefficient : float = 1.0
    shininess : float = 16.0
    falloff : float = 1.0
    cutoff_degrees : float = 45.0
    crop : FilterCrop = FilterCrop()
}

def public empty_filter() {
    var out : SkImageFilter?
    if (!Skia_EmptyFilter(out)) { return err(skia_error("empty_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public convolution_filter(kernel : array<float>; settings : ConvolutionOptions = ConvolutionOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_ConvolutionFilter(settings.size,kernel,settings.gain,settings.bias,settings.offset,settings.tile,settings.convolve_alpha,settings.crop.enabled,settings.crop.rect,input,out)) { return err(skia_error("convolution_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public displacement_filter(x,y : SkColorChannel; scale : float; displacement,color : SkImageFilter?; crop : FilterCrop = FilterCrop()) {
    var out : SkImageFilter?
    if (!Skia_DisplacementFilter(x,y,scale,displacement,color,crop.enabled,crop.rect,out)) { return err(skia_error("displacement_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public arithmetic_filter(coefficients : float4; background,foreground : SkImageFilter?; enforce_premul : bool = true; crop : FilterCrop = FilterCrop()) {
    var out : SkImageFilter?
    if (!Skia_ArithmeticFilter(coefficients,enforce_premul,background,foreground,crop.enabled,crop.rect,out)) { return err(skia_error("arithmetic_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public blend_image_filter(blender : SkBlender?; background,foreground : SkImageFilter?; crop : FilterCrop = FilterCrop()) {
    var out : SkImageFilter?
    if (!Skia_CustomBlendFilter(blender,background,foreground,crop.enabled,crop.rect,out)) { return err(skia_error("blend_image_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public tile_filter(source,destination : float4; input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_TileFilter(source,destination,input,out)) { return err(skia_error("tile_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public magnifier_filter(lens : float4; settings : MagnifierOptions = MagnifierOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_MagnifierFilter(lens,settings.zoom,settings.inset,settings.sampling.filter,settings.sampling.mipmap,settings.sampling.cubic,settings.sampling.b,settings.sampling.c,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("magnifier_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public shadow_only_filter(offset,sigma : float2; color : uint; input : SkImageFilter? = null; crop : FilterCrop = FilterCrop()) {
    var out : SkImageFilter?
    if (!Skia_ShadowOnlyFilter(offset,sigma,color,input,crop.enabled,crop.rect,out)) { return err(skia_error("shadow_only_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public distant_diffuse_filter(direction : float3; settings : LightingOptions = LightingOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_DistantDiffuseFilter(direction,settings.color,settings.surface_scale,settings.coefficient,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("distant_diffuse_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public distant_specular_filter(direction : float3; settings : LightingOptions = LightingOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_DistantSpecularFilter(direction,settings.color,settings.surface_scale,settings.coefficient,settings.shininess,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("distant_specular_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public point_diffuse_filter(location : float3; settings : LightingOptions = LightingOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_PointDiffuseFilter(location,settings.color,settings.surface_scale,settings.coefficient,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("point_diffuse_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public point_specular_filter(location : float3; settings : LightingOptions = LightingOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_PointSpecularFilter(location,settings.color,settings.surface_scale,settings.coefficient,settings.shininess,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("point_specular_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public spot_diffuse_filter(location : float3; target : float3; settings : LightingOptions = LightingOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_SpotDiffuseFilter(location,target,settings.falloff,settings.cutoff_degrees,settings.color,settings.surface_scale,settings.coefficient,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("spot_diffuse_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public spot_specular_filter(location : float3; target : float3; settings : LightingOptions = LightingOptions(); input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_SpotSpecularFilter(location,target,settings.falloff,settings.cutoff_degrees,settings.color,settings.surface_scale,settings.coefficient,settings.shininess,input,settings.crop.enabled,settings.crop.rect,out)) { return err(skia_error("spot_specular_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}
