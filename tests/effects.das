options gen2
require dasskia/skia_effects
require dasskia/skia_scope

def check_effect(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("effects_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def px(surface : SkSurface?; x,y : int) : uint {
    var color : uint
    Skia_ReadPixel(surface,x,y,color)
    return color
}
def test_effects() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(128,128))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(antialias=false)) |> skia_use
        let c = canvas(surface)
        var colors <- array(0xffff0000u,0xff0000ffu)
        var positions <- array(0.8,0.2)
        var bad <- linear_gradient(float2(0.0),float2(100.0,0.0),colors,positions)
        check_effect(is_err(bad),"reject unsorted gradient positions") |> skia_try
        positions[0]=0.0
        positions[1]=1.0
        linear_gradient(float2(0.0),float2(100.0,0.0),colors,positions) |> with_shader() $(s : SkShader?) {
            paint |> set_shader(s)
            return skia_ok()
        } |> skia_try
        // Paint retains shader; Skia copies gradient stops.
        colors[0]=0xff00ff00u
        c |> clear(0u)
        c |> draw_rect(float4(0.0,0.0,100.0,20.0),paint)
        let mid=px(surface,50,10)
        check_effect(((px(surface,0,10)>>16)&255u)>250u && (px(surface,99,10)&255u)>250u &&
            ((mid>>16)&255u)>120u && (mid&255u)>120u,"gradient pixels and retained ownership") |> skia_try
        paint |> set_shader()
        paint |> set_color(0xffff0000u)
        var swap <- array(0.0,0.0,1.0,0.0,0.0, 0.0,1.0,0.0,0.0,0.0, 1.0,0.0,0.0,0.0,0.0, 0.0,0.0,0.0,1.0,0.0)
        matrix_color_filter(swap) |> with_color_filter() $(f : SkColorFilter?) {
            paint |> set_color_filter(f)
            return skia_ok()
        } |> skia_try
        c |> draw_rect(float4(0.0,20.0,20.0,20.0),paint)
        check_effect(px(surface,10,30)==0xff0000ffu,"color matrix red to blue") |> skia_try
        var called=false
        blend_color_filter(0xffff0000u,SkBlendMode.Dst) |> with_color_filter() $(identity : SkColorFilter?) {
            called=true
            check_effect(identity==null,"identity filter is valid null") |> skia_try
            paint |> set_color_filter(identity)
            return skia_ok()
        } |> skia_try
        check_effect(called,"identity scope executes") |> skia_try
        var intervals <- array(8.0,8.0)
        dash_effect(intervals) |> with_path_effect() $(effect : SkPathEffect?) {
            paint |> set_path_effect(effect)
            return skia_ok()
        } |> skia_try
        paint |> set_stroke(true,4.0)
        c |> clear(0u)
        c |> draw_line(float2(0.0,20.0),float2(100.0,20.0),paint)
        check_effect(px(surface,3,20)==0xffff0000u && px(surface,11,20)==0u && px(surface,19,20)==0xffff0000u,"dash intervals") |> skia_try
        paint |> set_path_effect()
        paint |> set_stroke(false)
        blur_mask(3.0) |> with_mask_filter() $(f : SkMaskFilter?) {
            paint |> set_mask_filter(f)
            return skia_ok()
        } |> skia_try
        c |> clear(0u)
        c |> draw_rect(float4(30.0,30.0,30.0,30.0),paint)
        check_effect((px(surface,28,45)>>24)>0u && (px(surface,45,45)>>24)>240u,"mask blur spreads alpha") |> skia_try
        paint |> set_mask_filter()
        offset_filter(float2(20.0,10.0)) |> with_image_filter() $(f : SkImageFilter?) {
            paint |> set_image_filter(f)
            return skia_ok()
        } |> skia_try
        c |> clear(0u)
        c |> draw_rect(float4(10.0,10.0,10.0,10.0),paint)
        check_effect(px(surface,15,15)==0u && px(surface,35,25)==0xffff0000u,"image offset") |> skia_try
        dilate_filter(float2(3.0)) |> with_image_filter() $(f : SkImageFilter?) {
            paint |> set_image_filter(f)
            return skia_ok()
        } |> skia_try
        c |> clear(0u)
        c |> draw_rect(float4(30.0,30.0,30.0,30.0),paint)
        check_effect(px(surface,28,45)==0xffff0000u && px(surface,25,45)==0u,"dilate expands") |> skia_try
        erode_filter(float2(3.0)) |> with_image_filter() $(f : SkImageFilter?) {
            paint |> set_image_filter(f)
            return skia_ok()
        } |> skia_try
        c |> clear(0u)
        c |> draw_rect(float4(30.0,30.0,30.0,30.0),paint)
        check_effect(px(surface,31,45)==0u && px(surface,35,45)==0xffff0000u,"erode shrinks") |> skia_try
        blur_filter(float2(3.0)) |> with_image_filter() $(blur : SkImageFilter?) {
            offset_filter(float2(20.0,0.0),blur) |> with_image_filter() $(offset : SkImageFilter?) {
                paint |> set_image_filter(offset)
                return skia_ok()
            } |> skia_try
            return skia_ok()
        } |> skia_try
        c |> clear(0u)
        c |> draw_rect(float4(30.0,30.0,30.0,30.0),paint)
        check_effect((px(surface,48,45)>>24)>0u && (px(surface,65,45)>>24)>240u && px(surface,20,45)==0u,"filter chain retains inputs") |> skia_try
        paint |> reset_paint()
        // Nearest repeated image shader owns its image after the source scopes close.
        with_raster_surface(RasterSurfaceOptions(size=int2(2,1))) $(source : SkSurface?) {
            var pixels <- array(0xffff0000u,0xff0000ffu)
            source |> write_pixels(int4(0,0,2,1),pixels) |> skia_try
            source |> with_snapshot() $(image : SkImage?) {
                image_shader(image,ImageShaderOptions(tile_x=SkTileMode.Repeat)) |> with_shader() $(s : SkShader?) {
                    paint |> set_shader(s)
                    return skia_ok()
                } |> skia_try
                return skia_ok()
            } |> skia_try
            return skia_ok()
        } |> skia_try
        c |> clear(0u)
        c |> draw_rect(float4(0.0,0.0,20.0,20.0),paint)
        check_effect(px(surface,0,10)==0xffff0000u && px(surface,1,10)==0xff0000ffu && px(surface,2,10)==0xffff0000u,"image repeat and retained image") |> skia_try
        var zeros <- array(0.0,0.0)
        var invalid_dash <- dash_effect(zeros)
        var invalid_mask <- blur_mask(-1.0)
        var invalid_matrix <- matrix_color_filter(zeros)
        var invalid_blur <- blur_filter(float2(-1.0,0.0))
        check_effect(is_err(invalid_dash) && is_err(invalid_mask) && is_err(invalid_matrix) && is_err(invalid_blur),"invalid effect parameters") |> skia_try
        return skia_ok()
    }
}

def test_composition() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(128,128))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(antialias=false)) |> skia_use
        let c=canvas(surface)
        let red : SkShader? = solid_shader(0xffff0000u) |> with_shader() |> skia_use
        let blue : SkShader? = solid_shader(0xff0000ffu) |> with_shader() |> skia_use
        let blend : SkShader? = blend_shader(SkBlendMode.Multiply,red,blue) |> with_shader() |> skia_use
        let local : SkShader? = shader_with_matrix(blend,matrix_translation(float2(3.0))) |> with_shader() |> skia_use
        paint |> set_shader(local)
        c |> draw_paint(paint)
        check_effect(px(surface,50,50)==0xff000000u,"shader blend multiply") |> skia_try
        var colors <- array(0xffff0000u,0xff0000ffu)
        let repeated : SkShader? = linear_gradient(float2(0.0),float2(10.0,0.0),colors,GradientOptions(tile=SkTileMode.Repeat)) |> with_shader() |> skia_use
        paint |> set_shader(repeated)
        c |> draw_paint(paint)
        check_effect(px(surface,2,50)==px(surface,12,50),"gradient repeat") |> skia_try
        let radial : SkShader? = radial_gradient(float2(50.5),20.0,colors) |> with_shader() |> skia_use
        paint |> set_shader(radial)
        c |> draw_paint(paint)
        check_effect(px(surface,50,50)==0xffff0000u && px(surface,75,50)==0xff0000ffu,"radial center and outside") |> skia_try
        let sweep : SkShader? = sweep_gradient(float2(50.5),0.0,360.0,colors) |> with_shader() |> skia_use
        paint |> set_shader(sweep)
        c |> draw_paint(paint)
        check_effect(((px(surface,70,50)>>16)&255u)>250u && (px(surface,30,50)&255u)>120u,"sweep angles") |> skia_try
        let conical : SkShader? = conical_gradient(float2(50.5),0.0,float2(50.5),20.0,colors) |> with_shader() |> skia_use
        paint |> set_shader(conical)
        c |> draw_paint(paint)
        check_effect(px(surface,75,50)==0xff0000ffu,"conical outer color") |> skia_try
        paint |> reset_paint()
        paint |> set_antialias(false)
        paint |> set_color(0xffff0000u)
        let light : SkColorFilter? = lighting_color_filter(0xff80ffffu,0xff000000u) |> with_color_filter() |> skia_use
        let tint : SkColorFilter? = blend_color_filter(0xff0000ffu,SkBlendMode.Src) |> with_color_filter() |> skia_use
        let color_chain : SkColorFilter? = compose_color_filter(light,tint) |> with_color_filter() |> skia_use
        paint |> set_color_filter(color_chain)
        c |> draw_paint(paint)
        check_effect(px(surface,50,50)==0xff0000ffu,"color composition outer(inner(source))") |> skia_try
        let linear : SkColorFilter? = srgb_to_linear_filter() |> with_color_filter() |> skia_use
        let srgb : SkColorFilter? = linear_to_srgb_filter() |> with_color_filter() |> skia_use
        let gamma : SkColorFilter? = compose_color_filter(srgb,linear) |> with_color_filter() |> skia_use
        paint |> set_color_filter(gamma)
        paint |> set_color(0xff808080u)
        c |> draw_paint(paint)
        let channel=px(surface,50,50)&255u
        check_effect(channel>=127u && channel<=129u,"gamma roundtrip") |> skia_try
        paint |> set_color_filter()
        paint |> set_color(0xffff0000u)
        let offset : SkImageFilter? = offset_filter(float2(10.0,0.0)) |> with_image_filter() |> skia_use
        let colored : SkImageFilter? = color_filter_image(tint) |> with_image_filter() |> skia_use
        let chain : SkImageFilter? = compose_image_filter(colored,offset) |> with_image_filter() |> skia_use
        let cropped : SkImageFilter? = crop_filter(float4(30.0,20.0,10.0,20.0),chain) |> with_image_filter() |> skia_use
        paint |> set_image_filter(cropped)
        c |> clear(0u)
        c |> draw_rect(float4(20.0,20.0,20.0,20.0),paint)
        check_effect(px(surface,35,25)==0xff0000ffu && px(surface,45,25)==0u && px(surface,25,25)==0u,"image compose and crop") |> skia_try
        let blended : SkImageFilter? = blend_image_filter(SkBlendMode.SrcOver,offset,null) |> with_image_filter() |> skia_use
        paint |> set_image_filter(blended)
        c |> clear(0u)
        c |> draw_rect(float4(20.0,20.0,20.0,20.0),paint)
        check_effect(px(surface,25,25)==0xffff0000u && px(surface,45,25)==0xffff0000u,"image blend uses source for null input") |> skia_try
        let shadow : SkImageFilter? = drop_shadow_filter(float2(10.0),float2(0.0),0xff0000ffu) |> with_image_filter() |> skia_use
        paint |> set_image_filter(shadow)
        c |> clear(0u)
        c |> draw_rect(float4(20.0,20.0,10.0,10.0),paint)
        check_effect(px(surface,25,25)==0xffff0000u && px(surface,35,35)==0xff0000ffu,"drop shadow plus source") |> skia_try
        paint |> set_image_filter()
        let corner : SkPathEffect? = corner_effect(6.0) |> with_path_effect() |> skia_use
        var intervals <- array(8.0,4.0)
        let dash : SkPathEffect? = dash_effect(intervals,2.0) |> with_path_effect() |> skia_use
        let composed : SkPathEffect? = compose_path_effect(dash,corner) |> with_path_effect() |> skia_use
        let summed : SkPathEffect? = sum_path_effect(dash,corner) |> with_path_effect() |> skia_use
        let path : SkPath? = with_path() |> skia_use
        path |> move_to(float2(10.0,10.0))
        path |> line_to(float2(60.0,10.0))
        path |> line_to(float2(60.0,60.0))
        paint |> set_stroke(true,4.0)
        paint |> set_path_effect(composed)
        c |> clear(0u)
        c |> draw_path(path,paint)
        paint |> set_path_effect(summed)
        c |> draw_path(path,paint)
        check_effect(px(surface,30,10)!=0u,"composed and summed path effects") |> skia_try
        var called=false
        var invalid <- corner_effect(-1.0)
        let rejected=invalid |> with_path_effect() $(effect : SkPathEffect?) { called=true; return skia_ok() }
        check_effect(is_err(rejected) && !called,"factory Err skips scope body") |> skia_try
        let body_error=solid_shader(0xff000000u) |> with_shader() $(effect : SkShader?) {
            return err(skia_error("body","expected"),type<SkiaUnit>)
        }
        check_effect(is_err(body_error) && unwrap_err(body_error).operation=="body","scope preserves body Err") |> skia_try
        return skia_ok()
    }
}

[export]
def main() : int {
    let result=test_effects()
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    let composition=test_composition()
    if (is_err(composition)) { let e=unwrap_err(composition); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS effects: gradients, image shaders, dash, mask, color matrix, filter chains, ownership\n")
    return 0
}
