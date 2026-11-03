options gen2
require dasskia/skia_drawing
require dasskia/skia_scope
require math

def check_drawing(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("drawing_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def near_point(a,b : float2) : bool { return abs(a.x-b.x)<0.001 && abs(a.y-b.y)<0.001 }
def test_drawing() : SkiaStatus {
    let m = multiply(matrix_translation(float2(10.0,20.0)),matrix_scale(float2(2.0,3.0)))
    check_drawing(near_point(map_point(m,float2(4.0,5.0)),float2(18.0,35.0)),"matrix multiplication order") |> skia_try
    let inv = inverse(m)
    check_drawing(is_some(inv) && near_point(map_point(unwrap(inv),float2(18.0,35.0)),float2(4.0,5.0)),"matrix inverse") |> skia_try
    check_drawing(is_none(inverse(matrix_scale(float2(0.0,1.0)))),"singular inverse is None") |> skia_try
    var matrices : array<SkiaMatrix>
    resize(matrices,3)
    matrices[0] = m
    matrices[1] = matrix_rotation(90.0)
    check_drawing(near_point(map_point(matrices[0],float2(4.0,5.0)),float2(18.0,35.0)) &&
        near_point(map_point(matrices[1],float2(1.0,0.0)),float2(0.0,1.0)) && is_none(inverse(matrices[2])),"matrix array values and zero initialization") |> skia_try
    let perspective = matrix(float3(1.0,0.0,0.0),float3(0.0,1.0,0.0),float3(0.01,0.0,1.0))
    check_drawing(near_point(map_point(perspective,float2(10.0,0.0)),float2(10.0/1.1,0.0)),"perspective divide") |> skia_try
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(96,96))) |> skia_use
        let paint : SkPaint? = with_paint(PaintOptions(color=0xffff0000u,antialias=false,stroke_cap=SkStrokeCap.Square,
            stroke_join=SkStrokeJoin.Bevel,stroke_miter=2.5,blend_mode=SkBlendMode.Src)) |> skia_use
        let path : SkPath? = with_path() |> skia_use
        let c = canvas(surface)
        check_drawing(Skia_GetStrokeCap(paint)==SkStrokeCap.Square && Skia_GetStrokeJoin(paint)==SkStrokeJoin.Bevel &&
            Skia_GetStrokeMiter(paint)==2.5 && !Skia_GetAntialias(paint) && paint_blend_mode(paint)==SkBlendMode.Src,"paint descriptors") |> skia_try
        paint |> with_paint_copy() $(copy : SkPaint?) {
            copy |> reset_paint()
            check_drawing(paint_color(copy)==0xff000000u && paint_color(paint)==0xffff0000u,"paint copy independence") |> skia_try
            return skia_ok()
        } |> skia_try
        paint |> set_blend_mode(SkBlendMode.SrcOver)
        c |> set_matrix(m)
        check_drawing(near_point(map_point(canvas_matrix(c),float2(4.0,5.0)),float2(18.0,35.0)),"canvas matrix roundtrip") |> skia_try
        c |> reset_matrix()
        c |> concat(matrix_translation(float2(3.0,4.0)))
        c |> skew(float2(0.5,0.0))
        check_drawing(near_point(map_point(canvas_matrix(c),float2(2.0,2.0)),float2(6.0,6.0)),"concat and skew") |> skia_try
        c |> reset_matrix()
        check_drawing(path_empty(path),"new empty path") |> skia_try
        path |> add_rect(float4(2.0,3.0,10.0,20.0))
        check_drawing(path_bounds(path)==float4(2.0,3.0,10.0,20.0),"path bounds") |> skia_try
        path |> with_path_copy() $(copy : SkPath?) {
            copy |> transform(matrix_translation(float2(10.0,20.0)))
            copy |> offset(float2(1.0,2.0))
            check_drawing(path_bounds(copy)==float4(13.0,25.0,10.0,20.0) && path_bounds(path).x==2.0,"path copy and transform") |> skia_try
            path |> add_path(copy)
            return skia_ok()
        } |> skia_try
        check_drawing(contains(path,float2(15.0,30.0)),"add path") |> skia_try
        Skia_PathReset(path)
        path |> add_rect(float4(0.0,0.0,40.0,40.0))
        path |> add_rect(float4(10.0,10.0,20.0,20.0))
        path |> set_fill_type(SkPathFillType.EvenOdd)
        check_drawing(fill_type(path)==SkPathFillType.EvenOdd && !contains(path,float2(20.0,20.0)) && contains(path,float2(5.0,5.0)),"even-odd hole") |> skia_try
        path |> set_fill_type(SkPathFillType.InverseEvenOdd)
        check_drawing(contains(path,float2(20.0,20.0)) && !contains(path,float2(5.0,5.0)),"inverse fill") |> skia_try
        Skia_PathReset(path)
        path |> move_to(float2(0.0,0.0))
        path |> quad_to(float2(20.0,40.0),float2(40.0,0.0))
        check_drawing(path_bounds(path).w==40.0 && path_tight_bounds(path).w==20.0,"quadratic tight bounds") |> skia_try
        Skia_PathReset(path)
        path |> move_to(float2(0.0,0.0))
        path |> conic_to(float2(20.0,40.0),float2(40.0,0.0),1.0)
        check_drawing(abs(path_tight_bounds(path).w-20.0)<0.01,"conic") |> skia_try
        Skia_PathReset(path)
        path |> arc_to(float4(10.0,20.0,40.0,40.0),0.0,90.0,true)
        check_drawing(abs(path_tight_bounds(path).z-20.0)<0.01 && abs(path_tight_bounds(path).w-20.0)<0.01,"arc") |> skia_try
        Skia_PathReset(path)
        path |> add_round_rect(float4(8.0,8.0,48.0,32.0),float2(12.0,12.0))
        check_drawing(!contains(path,float2(9.0,9.0)) && contains(path,float2(25.0,20.0)),"rounded path") |> skia_try
        c |> clear(0xffffffffu)
        c |> draw_round_rect(float4(8.0,8.0,48.0,32.0),float2(12.0,12.0),paint)
        c |> draw_oval(float4(60.0,8.0,28.0,28.0),paint)
        c |> draw_arc(float4(50.0,50.0,40.0,40.0),0.0,90.0,true,paint)
        paint |> set_stroke(true,8.0)
        paint |> set_stroke_cap(SkStrokeCap.Round)
        paint |> set_stroke_join(SkStrokeJoin.Round)
        paint |> set_stroke_miter(3.0)
        check_drawing(Skia_GetStrokeWidth(paint)==8.0 && Skia_GetPaintStyle(paint)==SkPaintStyle.Stroke,"stroke width/style") |> skia_try
        c |> draw_line(float2(16.0,70.0),float2(40.0,70.0),paint)
        let corner = surface |> read_pixel(int2(9,9)) |> skia_try
        let rounded = surface |> read_pixel(int2(25,20)) |> skia_try
        let oval = surface |> read_pixel(int2(74,22)) |> skia_try
        let wedge = surface |> read_pixel(int2(80,80)) |> skia_try
        let cap = surface |> read_pixel(int2(14,70)) |> skia_try
        check_drawing(corner==0xffffffffu && rounded==0xffff0000u && oval==0xffff0000u && wedge==0xffff0000u && cap==0xffff0000u,"geometry pixels") |> skia_try
        paint |> set_style(SkPaintStyle.Fill)
        c |> clear(0xffff0000u)
        c |> with_saved() $(saved : SkCanvas?) {
            saved |> clip_rect(float4(10.0,10.0,20.0,20.0),SkClipOp.Difference)
            paint |> set_color(0xff0000ffu)
            saved |> draw_paint(paint)
            return skia_ok()
        } |> skia_try
        let hole = surface |> read_pixel(int2(15,15)) |> skia_try
        let outside = surface |> read_pixel(int2(1,1)) |> skia_try
        check_drawing(hole==0xffff0000u && outside==0xff0000ffu,"difference clip") |> skia_try
        Skia_PathReset(path)
        path |> add_oval(float4(40.0,40.0,40.0,40.0),SkPathDirection.CCW)
        c |> with_saved() $(saved : SkCanvas?) {
            saved |> clip_path(path)
            paint |> set_color(0xff00ff00u)
            saved |> draw_paint(paint)
            return skia_ok()
        } |> skia_try
        let clipped = surface |> read_pixel(int2(60,60)) |> skia_try
        check_drawing(clipped==0xff00ff00u,"path clip") |> skia_try
        let layer_paint : SkPaint? = with_paint(PaintOptions()) |> skia_use
        layer_paint |> set_alpha(0.5)
        check_drawing(abs(paint_alpha(layer_paint)-0.5)<0.01,"alpha query") |> skia_try
        c |> clear(0xffffffffu)
        paint |> set_color(0xffff0000u)
        let count = Skia_SaveCount(c)
        let layer_result = c |> with_layer(layer_paint) $(layer : SkCanvas?) {
            layer |> draw_rect(float4(10.0,10.0,40.0,40.0),paint)
            layer |> draw_rect(float4(30.0,10.0,40.0,40.0),paint)
            return err(skia_error("body","expected"),type<SkiaUnit>)
        }
        let single = surface |> read_pixel(int2(15,20)) |> skia_try
        let overlap = surface |> read_pixel(int2(35,20)) |> skia_try
        check_drawing(is_err(layer_result) && Skia_SaveCount(c)==count && single==overlap && ((single >> 8)&255u)>=126u && ((single >> 8)&255u)<=129u,"layer group opacity and Err cleanup") |> skia_try
        return skia_ok()
    }
}
def test_images() : SkiaStatus {
    return skia_scope() {
        let source : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(2,2))) |> skia_use
        let target : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(96,96))) |> skia_use
        var pixels <- array(0xffff0000u,0xff00ff00u,0xff0000ffu,0xffffffffu)
        source |> write_pixels(int4(0,0,2,2),pixels) |> skia_try
        var copied <- array(0u,0u,0u,0u,0xabcdef01u)
        source |> read_pixels(int4(0,0,2,2),copied) |> skia_try
        check_drawing(copied[0]==pixels[0] && copied[1]==pixels[1] && copied[2]==pixels[2] && copied[3]==pixels[3] && copied[4]==0xabcdef01u,"ARGB pixel roundtrip and tail") |> skia_try
        check_drawing(is_err(read_pixels(source,int4(2147483647,0,2,2),copied)) && is_err(write_pixels(source,int4(0,0,3,3),pixels)),"region overflow/bounds") |> skia_try
        var short_buffer <- array(0x12345678u)
        check_drawing(is_err(read_pixels(source,int4(0,0,2,2),short_buffer)) && short_buffer[0]==0x12345678u,"capacity check before mutation") |> skia_try
        let image : SkImage? = source |> with_snapshot() |> skia_use
        check_drawing(image_size(image)==int2(2,2),"image dimensions") |> skia_try
        check_drawing(is_err(image_subset(image,int4(1,0,2,1))),"subset bounds") |> skia_try
        let subset : SkImage? = image |> with_image_subset(int4(1,0,1,2)) |> skia_use
        let mipped : SkImage? = image |> with_mipmapped_image() |> skia_use
        check_drawing(image_size(subset)==int2(1,2) && image_size(mipped)==int2(2,2),"subset and mipmap dimensions") |> skia_try
        let c = canvas(target)
        c |> clear(0xff000000u)
        c |> draw_image_rect(image,float4(0.0,0.0,1.0,1.0),float4(8.0,8.0,32.0,32.0))
        c |> draw_image_to(image,float4(48.0,8.0,32.0,32.0))
        c |> draw_image_to(image,float4(0.0,48.0,32.0,32.0),SamplingOptions(filter=SkFilterMode.Linear))
        c |> draw_image_to(subset,float4(40.0,48.0,16.0,32.0))
        c |> draw_image(mipped,float2(70.0,50.0),SamplingOptions(filter=SkFilterMode.Linear,mipmap=SkMipmapMode.Linear))
        c |> draw_image_to(image,float4(70.0,70.0,16.0,16.0),SamplingOptions(cubic=true,b=0.0,c=0.5))
        let cropped = target |> read_pixel(int2(39,20)) |> skia_try
        let red = target |> read_pixel(int2(52,12)) |> skia_try
        let green = target |> read_pixel(int2(75,12)) |> skia_try
        let blue = target |> read_pixel(int2(52,35)) |> skia_try
        let filtered = target |> read_pixel(int2(16,64)) |> skia_try
        let sub = target |> read_pixel(int2(44,52)) |> skia_try
        check_drawing(cropped==0xffff0000u && red==0xffff0000u && green==0xff00ff00u && blue==0xff0000ffu && sub==0xff00ff00u,"crop/nearest/subset pixels") |> skia_try
        check_drawing(((filtered >> 16)&255u)>110u && ((filtered >> 16)&255u)<145u && ((filtered >> 8)&255u)>110u && ((filtered >> 8)&255u)<145u,"linear sampling mixes colors") |> skia_try
        return skia_ok()
    }
}
[export]
def main() : int {
    let geometry = test_drawing()
    if (is_err(geometry)) { let e=unwrap_err(geometry); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    let images = test_images()
    if (is_err(images)) { let e=unwrap_err(images); print("FAIL {e.operation}: {e.message}\n"); return 1 }
    print("PASS drawing: matrices, paths, paint, clips, layers, images, pixels\n")
    return 0
}
