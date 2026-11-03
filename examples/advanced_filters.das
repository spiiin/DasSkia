options gen2
require dasskia/skia_advanced_filters
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_scope

var window : SkiaWindow?
var paints : array<SkPaint?>
var labels : array<SkiaText?>
var ink : SkPaint?
var frames : int

def advanced_scene() {
    return record_picture(PictureOptions(bounds=float4(0.0,0.0,240.0,140.0))) $(c : SkCanvas?) {
        return skia_scope() {
            let paint : SkPaint? = with_paint(PaintOptions(color=0xff303b52u)) |> skia_use
            c |> draw_round_rect(float4(0.0,0.0,240.0,140.0),float2(16.0),paint)
            paint |> set_color(0xff39b5f0u)
            c |> draw_circle(float2(60.0,50.0),25.0,paint)
            paint |> set_color(0xff50d99au)
            c |> draw_round_rect(float4(120.0,25.0,80.0,50.0),float2(9.0),paint)
            let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
            var colors <- array(0xffff5d62u,0xfff4d36du,0xffc990f0u,0xff39b5f0u)
            source |> write_pixels(int4(0,0,2,2),colors) |> skia_try
            let image : SkImage? = source |> with_snapshot() |> skia_use
            c |> draw_image_to(image,float4(25.0,90.0,180.0,30.0))
            return skia_ok()
        }
    }
}
def create_advanced_filters() : SkiaStatus {
    return skia_scope() {
        let picture : SkPicture? = advanced_scene() |> with_picture() |> skia_use
        let base : SkImageFilter? = picture_source_filter(picture) |> with_image_filter() |> skia_use
        paints[0] |> set_image_filter(base)
        var sharpen <- array(0.0,-1.0,0.0, -1.0,5.0,-1.0, 0.0,-1.0,0.0)
        let crop=FilterCrop(enabled=true,rect=float4(0.0,0.0,240.0,140.0))
        let convolution : SkImageFilter? = convolution_filter(sharpen,ConvolutionOptions(tile=SkTileMode.Clamp,crop=crop),base) |> with_image_filter() |> skia_use
        paints[1] |> set_image_filter(convolution)
        let displacement_shader : SkShader? = solid_shader(0xffff8000u) |> with_shader() |> skia_use
        let displacement_map : SkImageFilter? = shader_source_filter(displacement_shader) |> with_image_filter() |> skia_use
        let displacement : SkImageFilter? = displacement_filter(SkColorChannel.R,SkColorChannel.G,20.0,displacement_map,base,crop) |> with_image_filter() |> skia_use
        paints[2] |> set_image_filter(displacement)
        let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
        var pixels <- array(0xffff5d62u,0xfff4d36du,0xffc990f0u,0xff39b5f0u)
        source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
        let image : SkImage? = source |> with_snapshot() |> skia_use
        let overlay : SkImageFilter? = image_source_filter(image,float4(0.0,0.0,240.0,140.0)) |> with_image_filter() |> skia_use
        let arithmetic : SkImageFilter? = arithmetic_filter(float4(0.0,0.5,0.5,0.0),base,overlay,true,crop) |> with_image_filter() |> skia_use
        paints[3] |> set_image_filter(arithmetic)
        let tiled : SkImageFilter? = tile_filter(float4(35.0,25.0,60.0,60.0),float4(0.0,0.0,240.0,140.0),base) |> with_image_filter() |> skia_use
        paints[4] |> set_image_filter(tiled)
        let magnified : SkImageFilter? = magnifier_filter(float4(20.0,20.0,200.0,100.0),MagnifierOptions(zoom=2.0,inset=12.0),base) |> with_image_filter() |> skia_use
        paints[5] |> set_image_filter(magnified)
        var heights <- array(0xffffffffu,0x00ffffffu)
        let radial : SkShader? = radial_gradient(float2(120.0,70.0),55.0,heights) |> with_shader() |> skia_use
        let height : SkImageFilter? = shader_source_filter(radial) |> with_image_filter() |> skia_use
        let material=LightingOptions(color=0xffffd36du,surface_scale=35.0,coefficient=0.85,shininess=20.0,crop=crop)
        let diffuse : SkImageFilter? = distant_diffuse_filter(float3(-1.0,-1.0,1.0),material,height) |> with_image_filter() |> skia_use
        let specular : SkImageFilter? = distant_specular_filter(float3(-1.0,-1.0,1.0),material,height) |> with_image_filter() |> skia_use
        let spot : SkImageFilter? = spot_diffuse_filter(float3(90.0,10.0,80.0),float3(120.0,70.0,0.0),material,height) |> with_image_filter() |> skia_use
        paints[6] |> set_image_filter(diffuse)
        paints[7] |> set_image_filter(specular)
        paints[8] |> set_image_filter(spot)
        return skia_ok()
    }
}
def advanced_init() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia - Image processing and lighting",size=int2(900,740))) |> skia_try
    ink=create_paint(PaintOptions(color=0xffe8edf8u))
    resize(paints,9)
    for (i in range(9)) { paints[i]=create_paint(PaintOptions()) }
    create_advanced_filters() |> skia_try
    return with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=18.0)) $(font : SkFont?) {
        var names <- array("Image processing / native Skia filters","Original source","3x3 sharpen convolution","RG displacement",
            "Arithmetic mix","Tile + destination crop","Magnifier / inset lens","Diffuse lighting","Specular lighting","Spot lighting",
            "Alpha as height / immutable filter graphs / desktop + web")
        resize(labels,length(names))
        for (i in range(length(names))) {
            var text=shape_text(font,names[i],TextOptions()) |> skia_try
            labels[i]=text
        }
        return skia_ok()
    }
}
def advanced_draw(c : SkCanvas?) : SkiaStatus {
    c |> clear(0xff181c28u)
    c |> draw_text(labels[0],float2(40.0,25.0),ink)
    for (i in range(9)) {
        let position=float2(40.0+float(i%3)*300.0,75.0+float(i/3)*210.0)
        c |> with_saved() $(saved : SkCanvas?) {
            saved |> translate(position)
            saved |> clip_rect(float4(0.0,0.0,240.0,140.0))
            saved |> draw_paint(paints[i])
            return skia_ok()
        } |> skia_try
        c |> draw_text(labels[i+1],position+float2(0.0,155.0),ink)
    }
    c |> draw_text(labels[10],float2(40.0,705.0),ink)
    return skia_ok()
}
def advanced_report(result : SkiaStatus) : int {
    if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return -1 }
    return 0
}
[export]
def app_init() : int { return advanced_report(advanced_init()) }
[export]
def app_frame() : int {
    if (!poll_window(window)) { return 1 }
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.operation}: {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) { return advanced_draw(c) }
    frames++
    if (frames==3) { print("PASS advanced filters frame 3\n") }
    return advanced_report(result)
}
[export]
def app_quit() {
    for (paint in paints) { Skia_DeletePaint(paint) }
    for (text in labels) { destroy_text(text) }
    clear(paints); clear(labels)
    Skia_DeletePaint(ink);ink=null
    destroy_window(window);window=null
}
