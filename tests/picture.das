options gen2
require dasskia/skia_picture
require dasskia/skia_text
require dasskia/skia_scope
require math

def check_picture(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("picture_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def make_fixture() {
    return record_picture(PictureOptions(bounds=float4(0.0,0.0,96.0,96.0))) $(c : SkCanvas?) {
        return skia_scope() {
            let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
            c |> draw_rect(float4(8.0,8.0,32.0,32.0),paint)
            paint |> set_color(0xff0000ffu)
            c |> draw_circle(float2(64.0,24.0),16.0,paint)
            let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
            var colors <- array(0xffff0000u,0xff00ff00u,0xff0000ffu,0xffffffffu)
            source |> write_pixels(int4(0,0,2,2),colors) |> skia_try
            let image : SkImage? = source |> with_snapshot() |> skia_use
            c |> draw_image_to(image,float4(8.0,48.0,32.0,32.0))
            let font : SkFont? = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=14.0)) |> skia_use
            let text : SkiaText? = font |> with_shaped_text("Skia",TextOptions()) |> skia_use
            paint |> set_color(0xffffffffu)
            c |> draw_text(text,float2(44.0,54.0),paint)
            var stops <- array(0xffff0000u,0xff0000ffu)
            let shader : SkShader? = linear_gradient(float2(44.0,0.0),float2(84.0,0.0),stops) |> with_shader() |> skia_use
            paint |> set_shader(shader)
            c |> draw_rect(float4(44.0,76.0,40.0,12.0),paint)
            return skia_ok()
        }
    }
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
def test_pictures() : SkiaStatus {
    return skia_scope() {
        let picture : SkPicture? = make_fixture() |> with_picture() |> skia_use
        verify_fixture(picture) |> skia_try
        let stats=picture_stats(picture)
        check_picture(stats.id!=0u && stats.operations>0 && stats.bytes>0ul && stats.cull==float4(0.0,0.0,96.0,96.0),"picture stats") |> skia_try
        var bytes=serialize_picture(picture) |> skia_try
        check_picture(length(bytes)>1000,"serialized resources") |> skia_try
        let copy : SkPicture? = picture_from_bytes(bytes) |> with_picture() |> skia_use
        clear(bytes)
        verify_fixture(copy) |> skia_try
        check_picture(picture_stats(copy).id!=stats.id,"deserialized picture gets process identity") |> skia_try
        picture |> save_picture("picture-roundtrip.skp") |> skia_try
        let file : SkPicture? = load_picture("picture-roundtrip.skp") |> with_picture() |> skia_use
        verify_fixture(file) |> skia_try
        check_picture(is_err(save_picture(picture,"missing-picture-directory/test.skp")),"file write error") |> skia_try
        var empty : array<uint8>
        var junk <- array(uint8(1),uint8(2),uint8(3))
        var badempty <- picture_from_bytes(empty)
        var badjunk <- picture_from_bytes(junk)
        var missing <- load_picture("missing-picture-file.skp")
        check_picture(is_err(badempty) && is_err(badjunk) && is_err(missing),"invalid data/file") |> skia_try
        let parent : SkPicture? = record_picture(PictureOptions(bounds=stats.cull)) $(c : SkCanvas?) {
            return make_fixture() |> with_picture() $(child : SkPicture?) {
                c |> draw_picture(child)
                return skia_ok()
            }
        } |> with_picture() |> skia_use
        verify_fixture(parent) |> skia_try
        // Direct playback is also available for replaying individual commands.
        let replayed : SkPicture? = record_picture(PictureOptions(bounds=stats.cull)) $(c : SkCanvas?) {
            picture |> playback_picture(c)
            return skia_ok()
        } |> with_picture() |> skia_use
        verify_fixture(replayed) |> skia_try
        var called=false
        let failure=record_picture(PictureOptions(bounds=float4(0.0,0.0,-1.0,10.0))) $(c : SkCanvas?) { called=true; return skia_ok() }
        check_picture(is_err(failure) && !called,"invalid bounds skip recorder body") |> skia_try
        let body_failure=record_picture(PictureOptions()) $(c : SkCanvas?) { return err(skia_error("body","expected"),type<SkiaUnit>) }
        check_picture(is_err(body_failure) && unwrap_err(body_failure).operation=="body","recording preserves body Err") |> skia_try
        let scope_failure=make_fixture() |> with_picture() $(borrowed : SkPicture?) { return err(skia_error("scope","expected"),type<SkiaUnit>) }
        check_picture(is_err(scope_failure) && unwrap_err(scope_failure).operation=="scope","picture scope preserves Err") |> skia_try
        return skia_ok()
    }
}
def test_recorder() : SkiaStatus {
    return skia_scope() {
        let recorder : SkPictureRecorder? = with_picture_recorder() |> skia_use
        check_picture(recording_canvas(recorder)==null,"new recorder inactive") |> skia_try
        var inactive <- finish_recording(recorder)
        check_picture(is_err(inactive),"inactive finish rejected") |> skia_try
        var begun <- begin_recording(recorder,PictureOptions(bounds=float4(0.0,0.0,64.0,64.0)))
        let c=move_unwrap(begun)
        var twice <- begin_recording(recorder)
        check_picture(is_err(twice) && recording_canvas(recorder)==c,"double begin preserves active canvas") |> skia_try
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false)) |> skia_use
        c |> draw_rect(float4(0.0,0.0,30.0,20.0),paint)
        c |> draw_rect(float4(15.0,0.0,30.0,20.0),paint)
        // Finish balances outstanding saves; replay must not affect destination state.
        Skia_Save(c)
        c |> translate(float2(7.0,9.0))
        var invalid <- finish_recording(recorder,float4(0.0,0.0,-1.0,1.0))
        check_picture(is_err(invalid) && recording_canvas(recorder)==c,"invalid cull leaves recording active") |> skia_try
        let picture : SkPicture? = finish_recording(recorder,float4(0.0,0.0,48.0,32.0)) |> with_picture() |> skia_use
        check_picture(recording_canvas(recorder)==null && picture_stats(picture).cull==float4(0.0,0.0,48.0,32.0),"finish invalidates canvas and sets cull") |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(96,64))) |> skia_use
        let target=canvas(surface)
        target |> clear(0xffffffffu)
        paint |> set_alpha(0.5)
        let saved=Skia_SaveCount(target)
        target |> draw_picture(picture,matrix_translation(float2(10.0,10.0)),paint)
        let single=surface |> read_pixel(int2(15,15)) |> skia_try
        let overlap=surface |> read_pixel(int2(30,15)) |> skia_try
        check_picture(single==overlap && ((single>>8)&255u)>=126u && ((single>>8)&255u)<=129u,"picture paint applies group opacity") |> skia_try
        check_picture(Skia_SaveCount(target)==saved && map_point(canvas_matrix(target),float2(0.0))==float2(0.0),"draw_picture restores canvas state") |> skia_try
        var again <- begin_recording(recorder,PictureOptions(bbh=true))
        let reused=move_unwrap(again)
        reused |> draw_rect(float4(2.0,3.0,4.0,5.0),paint)
        let indexed : SkPicture? = finish_recording(recorder) |> with_picture() |> skia_use
        check_picture(picture_stats(indexed).operations>0,"recorder reuse with R-tree") |> skia_try
        var empty_begin <- begin_recording(recorder)
        let empty : SkPicture? = finish_recording(recorder) |> with_picture() |> skia_use
        check_picture(picture_stats(empty).operations==0,"empty recording succeeds") |> skia_try
        return skia_ok()
    }
}
def test_picture_shader() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(48,24))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(antialias=false)) |> skia_use
        // The paint retains the shader, which retains the source picture.
        record_picture(PictureOptions(bounds=float4(0.0,0.0,16.0,16.0))) $(c : SkCanvas?) {
            paint |> set_color(0xffff0000u)
            c |> draw_rect(float4(0.0,0.0,8.0,16.0),paint)
            paint |> set_color(0xff0000ffu)
            c |> draw_rect(float4(8.0,0.0,8.0,16.0),paint)
            return skia_ok()
        } |> with_picture() $(picture : SkPicture?) {
            return skia_scope() {
            picture_shader(picture,PictureShaderOptions(filter=SkFilterMode.Nearest)) |> with_shader() $(shader : SkShader?) {
                paint |> set_shader(shader)
                return skia_ok()
            } |> skia_try
            let custom : SkShader? = picture_shader(picture,PictureShaderOptions(filter=SkFilterMode.Nearest,custom_tile=true,
                tile=float4(0.0,0.0,8.0,16.0),local_matrix=matrix_scale(float2(2.0)))) |> with_shader() |> skia_use
            let copy : SkPaint? = paint |> with_paint_copy() |> skia_use
            copy |> set_shader(custom)
            let c=canvas(surface)
            c |> draw_rect(float4(0.0,16.0,48.0,8.0),copy)
            var invalid <- picture_shader(picture,PictureShaderOptions(custom_tile=true,tile=float4(0.0,0.0,-1.0,1.0)))
            check_picture(is_err(invalid),"invalid shader tile") |> skia_try
            return skia_ok()
            }
        } |> skia_try
        let c=canvas(surface)
        c |> draw_rect(float4(0.0,0.0,48.0,16.0),paint)
        let a=surface |> read_pixel(int2(1,8)) |> skia_try
        let b=surface |> read_pixel(int2(9,8)) |> skia_try
        let repeated=surface |> read_pixel(int2(17,8)) |> skia_try
        let cropped=surface |> read_pixel(int2(17,20)) |> skia_try
        check_picture(a==0xffff0000u && b==0xff0000ffu && repeated==a && cropped==a,"picture shader repeat, crop and retained ownership") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    for (result in fixed_array(test_pictures(),test_recorder(),test_picture_shader())) {
        if (is_err(result)) { let e=unwrap_err(result); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    }
    print("PASS picture: recording, replay, serialization, images, embedded fonts, recorder state, group opacity, shaders\n")
    return 0
}
