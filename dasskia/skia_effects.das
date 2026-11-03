options gen2
require daslib/defer
module skia_effects shared public
require dasskia/skia_drawing public

struct GradientOptions {
    tile : SkTileMode = SkTileMode.Clamp
    premul : bool = false
    local_matrix : SkiaMatrix = matrix()
}
struct ImageShaderOptions {
    tile_x : SkTileMode = SkTileMode.Clamp
    tile_y : SkTileMode = SkTileMode.Clamp
    sampling : SamplingOptions = SamplingOptions()
    local_matrix : SkiaMatrix = matrix()
}

def public solid_shader(color : uint) {
    var out : SkShader?
    if (!Skia_SolidShader(color,out)) { return err(skia_error("solid_shader",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public linear_gradient(start,end : float2; colors : array<uint>; positions : array<float>; settings : GradientOptions = GradientOptions()) {
    var out : SkShader?
    if (!Skia_LinearGradient(start,end,colors,positions,settings.tile,settings.premul,settings.local_matrix,out)) { return err(skia_error("linear_gradient",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public linear_gradient(start,end : float2; colors : array<uint>; settings : GradientOptions = GradientOptions()) {
    var positions : array<float>
    return <- linear_gradient(start,end,colors,positions,settings)
}

def public radial_gradient(center : float2; radius : float; colors : array<uint>; positions : array<float>; settings : GradientOptions = GradientOptions()) {
    var out : SkShader?
    if (!Skia_RadialGradient(center,radius,colors,positions,settings.tile,settings.premul,settings.local_matrix,out)) { return err(skia_error("radial_gradient",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public radial_gradient(center : float2; radius : float; colors : array<uint>; settings : GradientOptions = GradientOptions()) {
    var positions : array<float>
    return <- radial_gradient(center,radius,colors,positions,settings)
}

def public sweep_gradient(center : float2; start_degrees,end_degrees : float; colors : array<uint>; positions : array<float>; settings : GradientOptions = GradientOptions()) {
    var out : SkShader?
    if (!Skia_SweepGradient(center,start_degrees,end_degrees,colors,positions,settings.tile,settings.premul,settings.local_matrix,out)) { return err(skia_error("sweep_gradient",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public sweep_gradient(center : float2; start_degrees,end_degrees : float; colors : array<uint>; settings : GradientOptions = GradientOptions()) {
    var positions : array<float>
    return <- sweep_gradient(center,start_degrees,end_degrees,colors,positions,settings)
}

def public conical_gradient(start : float2; start_radius : float; end : float2; end_radius : float; colors : array<uint>; positions : array<float>; settings : GradientOptions = GradientOptions()) {
    var out : SkShader?
    if (!Skia_ConicalGradient(start,start_radius,end,end_radius,colors,positions,settings.tile,settings.premul,settings.local_matrix,out)) { return err(skia_error("conical_gradient",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public conical_gradient(start : float2; start_radius : float; end : float2; end_radius : float; colors : array<uint>; settings : GradientOptions = GradientOptions()) {
    var positions : array<float>
    return <- conical_gradient(start,start_radius,end,end_radius,colors,positions,settings)
}

def public image_shader(image : SkImage?; settings : ImageShaderOptions = ImageShaderOptions()) {
    var out : SkShader?
    if (!Skia_ImageShader(image,settings.tile_x,settings.tile_y,settings.sampling.filter,settings.sampling.mipmap,settings.sampling.cubic,settings.sampling.b,settings.sampling.c,settings.local_matrix,out)) { return err(skia_error("image_shader",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public blend_shader(mode : SkBlendMode; destination,source : SkShader?) {
    var out : SkShader?
    if (!Skia_BlendShader(mode,destination,source,out)) { return err(skia_error("blend_shader",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public shader_with_matrix(shader : SkShader?; local : SkiaMatrix) {
    var out : SkShader?
    if (!Skia_LocalShader(shader,local,out)) { return err(skia_error("shader_with_matrix",Skia_EffectsError()),type<SkShader?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public dash_effect(intervals : array<float>; phase : float = 0.0) {
    var out : SkPathEffect?
    if (!Skia_DashEffect(intervals,phase,out)) { return err(skia_error("dash_effect",Skia_EffectsError()),type<SkPathEffect?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public corner_effect(radius : float) {
    var out : SkPathEffect?
    if (!Skia_CornerEffect(radius,out)) { return err(skia_error("corner_effect",Skia_EffectsError()),type<SkPathEffect?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public compose_path_effect(outer,inner : SkPathEffect?) {
    var out : SkPathEffect?
    if (!Skia_ComposePathEffect(outer,inner,out)) { return err(skia_error("compose_path_effect",Skia_EffectsError()),type<SkPathEffect?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public sum_path_effect(outer,inner : SkPathEffect?) {
    var out : SkPathEffect?
    if (!Skia_SumPathEffect(outer,inner,out)) { return err(skia_error("sum_path_effect",Skia_EffectsError()),type<SkPathEffect?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public blur_mask(sigma : float; style : SkBlurStyle = SkBlurStyle.Normal; respect_ctm : bool = true) {
    var out : SkMaskFilter?
    if (!Skia_BlurMask(style,sigma,respect_ctm,out)) { return err(skia_error("blur_mask",Skia_EffectsError()),type<SkMaskFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public blend_color_filter(color : uint; mode : SkBlendMode) {
    var out : SkColorFilter?
    if (!Skia_BlendColorFilter(color,mode,out)) { return err(skia_error("blend_color_filter",Skia_EffectsError()),type<SkColorFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public matrix_color_filter(values : array<float>) {
    var out : SkColorFilter?
    if (!Skia_MatrixColorFilter(values,out)) { return err(skia_error("matrix_color_filter",Skia_EffectsError()),type<SkColorFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public compose_color_filter(outer,inner : SkColorFilter?) {
    var out : SkColorFilter?
    if (!Skia_ComposeColorFilter(outer,inner,out)) { return err(skia_error("compose_color_filter",Skia_EffectsError()),type<SkColorFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public lighting_color_filter(multiply,add : uint) {
    var out : SkColorFilter?
    if (!Skia_LightingColorFilter(multiply,add,out)) { return err(skia_error("lighting_color_filter",Skia_EffectsError()),type<SkColorFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public linear_to_srgb_filter() {
    var out : SkColorFilter?
    if (!Skia_LinearToSRGBFilter(out)) { return err(skia_error("linear_to_srgb_filter",Skia_EffectsError()),type<SkColorFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public srgb_to_linear_filter() {
    var out : SkColorFilter?
    if (!Skia_SRGBToLinearFilter(out)) { return err(skia_error("srgb_to_linear_filter",Skia_EffectsError()),type<SkColorFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public blur_filter(sigma : float2; input : SkImageFilter? = null; tile : SkTileMode = SkTileMode.Decal) {
    var out : SkImageFilter?
    if (!Skia_BlurImageFilter(sigma,tile,input,out)) { return err(skia_error("blur_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public drop_shadow_filter(offset,sigma : float2; color : uint; input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_ShadowImageFilter(offset,sigma,color,input,out)) { return err(skia_error("drop_shadow_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public offset_filter(offset : float2; input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_OffsetImageFilter(offset,input,out)) { return err(skia_error("offset_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public dilate_filter(radius : float2; input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_DilateImageFilter(radius,input,out)) { return err(skia_error("dilate_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public erode_filter(radius : float2; input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_ErodeImageFilter(radius,input,out)) { return err(skia_error("erode_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public color_filter_image(color : SkColorFilter?; input : SkImageFilter? = null) {
    var out : SkImageFilter?
    if (!Skia_ColorImageFilter(color,input,out)) { return err(skia_error("color_filter_image",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public compose_image_filter(outer,inner : SkImageFilter?) {
    var out : SkImageFilter?
    if (!Skia_ComposeImageFilter(outer,inner,out)) { return err(skia_error("compose_image_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public blend_image_filter(mode : SkBlendMode; background,foreground : SkImageFilter?) {
    var out : SkImageFilter?
    if (!Skia_BlendImageFilter(mode,background,foreground,out)) { return err(skia_error("blend_image_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public crop_filter(rect : float4; input : SkImageFilter? = null; tile : SkTileMode = SkTileMode.Decal) {
    var out : SkImageFilter?
    if (!Skia_CropImageFilter(rect,tile,input,out)) { return err(skia_error("crop_filter",Skia_EffectsError()),type<SkImageFilter?>) }
    return <- move_ok(out,type<SkiaError>)
}

def public set_shader(paint : SkPaint?; effect : SkShader? = null) { Skia_SetShader(paint,effect) }

// Consumes a successful factory result, including valid null identity filters.
def public with_shader(var created : $Result<SkShader?;SkiaError>; blk : block<(effect : SkShader?) : $Result<auto(EffectBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<EffectBodyResult>) }
    let effect = move_unwrap(created)
    var result : $Result<EffectBodyResult;SkiaError>
    {
        defer() { Skia_ShaderUnref(effect) }
        static_if (typeinfo can_copy(type<$Result<EffectBodyResult;SkiaError>>)) { result = blk(effect) } else { result <- blk(effect) }
    }
    return <- result
}

def public set_path_effect(paint : SkPaint?; effect : SkPathEffect? = null) { Skia_SetPathEffect(paint,effect) }

// Consumes a successful factory result, including valid null identity filters.
def public with_path_effect(var created : $Result<SkPathEffect?;SkiaError>; blk : block<(effect : SkPathEffect?) : $Result<auto(EffectBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<EffectBodyResult>) }
    let effect = move_unwrap(created)
    var result : $Result<EffectBodyResult;SkiaError>
    {
        defer() { Skia_PathEffectUnref(effect) }
        static_if (typeinfo can_copy(type<$Result<EffectBodyResult;SkiaError>>)) { result = blk(effect) } else { result <- blk(effect) }
    }
    return <- result
}

def public set_mask_filter(paint : SkPaint?; effect : SkMaskFilter? = null) { Skia_SetMaskFilter(paint,effect) }

// Consumes a successful factory result, including valid null identity filters.
def public with_mask_filter(var created : $Result<SkMaskFilter?;SkiaError>; blk : block<(effect : SkMaskFilter?) : $Result<auto(EffectBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<EffectBodyResult>) }
    let effect = move_unwrap(created)
    var result : $Result<EffectBodyResult;SkiaError>
    {
        defer() { Skia_MaskFilterUnref(effect) }
        static_if (typeinfo can_copy(type<$Result<EffectBodyResult;SkiaError>>)) { result = blk(effect) } else { result <- blk(effect) }
    }
    return <- result
}

def public set_color_filter(paint : SkPaint?; effect : SkColorFilter? = null) { Skia_SetColorFilter(paint,effect) }

// Consumes a successful factory result, including valid null identity filters.
def public with_color_filter(var created : $Result<SkColorFilter?;SkiaError>; blk : block<(effect : SkColorFilter?) : $Result<auto(EffectBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<EffectBodyResult>) }
    let effect = move_unwrap(created)
    var result : $Result<EffectBodyResult;SkiaError>
    {
        defer() { Skia_ColorFilterUnref(effect) }
        static_if (typeinfo can_copy(type<$Result<EffectBodyResult;SkiaError>>)) { result = blk(effect) } else { result <- blk(effect) }
    }
    return <- result
}

def public set_image_filter(paint : SkPaint?; effect : SkImageFilter? = null) { Skia_SetImageFilter(paint,effect) }

// Consumes a successful factory result, including valid null identity filters.
def public with_image_filter(var created : $Result<SkImageFilter?;SkiaError>; blk : block<(effect : SkImageFilter?) : $Result<auto(EffectBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<EffectBodyResult>) }
    let effect = move_unwrap(created)
    var result : $Result<EffectBodyResult;SkiaError>
    {
        defer() { Skia_ImageFilterUnref(effect) }
        static_if (typeinfo can_copy(type<$Result<EffectBodyResult;SkiaError>>)) { result = blk(effect) } else { result <- blk(effect) }
    }
    return <- result
}
