options gen2
require dasskia/skia_codecs
require dasskia/skia_scope
require daslib/defer
require math

def check_codec(value : bool; message : string) : SkiaStatus {
    if (!value) {return err(skia_error("codec_test",message),type<SkiaUnit>)}
    return skia_ok()
}
def near_codec(a,b : uint; tolerance : int) : bool {
    for (shift in range(4)) {if (abs(int((a >> uint(shift*8))&255u)-int((b >> uint(shift*8))&255u))>tolerance) {return false}}
    return true
}
def decoded_pixel(image : SkImage?; position : int2; expected : uint; tolerance : int) : SkiaStatus {
    return with_raster_surface(RasterSurfaceOptions(size=image_size(image))) $(surface : SkSurface?) {
        canvas(surface) |> clear(0u)
        canvas(surface) |> draw_image(image,float2(0.0))
        let color=surface |> read_pixel(position) |> skia_try
        check_codec((color >> 24)==(expected >> 24),"decoded alpha is exact") |> skia_try
        return check_codec(near_codec(color,expected,tolerance),"decoded pixel {color} expected {expected} tolerance {tolerance}")
    }
}
def codec_tests() : SkiaStatus {
    return skia_scope() {
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(64,48))) |> skia_use
        canvas(surface) |> clear(0xff39b5f0u)
        var png <- surface |> encode_png() |> skia_try
        var jpeg <- surface |> encode_jpeg(JpegOptions(quality=100,downsample=SkiaJpegDownsample.YUV444)) |> skia_try
        var lossy <- surface |> encode_webp(WebpOptions(quality=90.0)) |> skia_try
        var lossless <- surface |> encode_webp(WebpOptions(quality=75.0,compression=SkiaWebpCompression.Lossless)) |> skia_try
        check_codec(length(png)>8 && png[0]==137 && png[1]==80,"PNG magic") |> skia_try
        check_codec(length(jpeg)>3 && jpeg[0]==255 && jpeg[1]==216,"JPEG magic") |> skia_try
        check_codec(length(lossless)>12 && lossless[0]==82 && lossless[8]==87 && lossless[9]==69 && lossless[10]==66 && lossless[11]==80,"WebP RIFF magic") |> skia_try
        let p : SkImage? = with_image_bytes(png) |> skia_use
        let j : SkImage? = with_image_bytes(jpeg) |> skia_use
        let w : SkImage? = with_image_bytes(lossy) |> skia_use
        let l : SkImage? = with_image_bytes(lossless) |> skia_use
        check_codec(image_size(j)==int2(64,48) && image_size(w)==int2(64,48),"decoded dimensions") |> skia_try
        decoded_pixel(p,int2(20,20),0xff39b5f0u,0) |> skia_try
        decoded_pixel(j,int2(20,20),0xff39b5f0u,3) |> skia_try
        decoded_pixel(w,int2(20,20),0xff39b5f0u,5) |> skia_try
        decoded_pixel(l,int2(20,20),0xff39b5f0u,0) |> skia_try
        // Copied encoded storage survives source array mutation before lazy decode.
        var owned=image_from_bytes(lossless) |> skia_try
        {
            defer() {Skia_ImageUnref(owned)}
            for (i in range(length(lossless))) {lossless[i]=0}
            resize(lossless,0)
            decoded_pixel(owned,int2(20,20),0xff39b5f0u,0) |> skia_try
        }
        surface |> save_jpeg("codec-roundtrip.jpg",JpegOptions(quality=100,downsample=SkiaJpegDownsample.YUV444)) |> skia_try
        surface |> save_webp("codec-roundtrip-lossy.webp",WebpOptions(quality=90.0)) |> skia_try
        let jf : SkImage? = with_image_file("codec-roundtrip.jpg") |> skia_use
        let wf : SkImage? = with_image_file("codec-roundtrip-lossy.webp") |> skia_use
        decoded_pixel(jf,int2(20),0xff39b5f0u,3) |> skia_try
        decoded_pixel(wf,int2(20),0xff39b5f0u,5) |> skia_try
        surface |> save_jpeg("codec-content.bin",JpegOptions(quality=100,downsample=SkiaJpegDownsample.YUV444)) |> skia_try
        let sniff : SkImage? = with_image_file("codec-content.bin") |> skia_use
        decoded_pixel(sniff,int2(20),0xff39b5f0u,3) |> skia_try
        canvas(surface) |> clear(0x80ff4000u)
        surface |> save_webp("codec-roundtrip-alpha.webp",WebpOptions(quality=75.0,compression=SkiaWebpCompression.Lossless)) |> skia_try
        var alpha <- surface |> encode_webp(WebpOptions(compression=SkiaWebpCompression.Lossless)) |> skia_try
        let a : SkImage? = with_image_bytes(alpha) |> skia_use
        decoded_pixel(a,int2(20),0x80ff4000u,0) |> skia_try
        let af : SkImage? = with_image_file("codec-roundtrip-alpha.webp") |> skia_use
        decoded_pixel(af,int2(20),0x80ff4000u,0) |> skia_try
        surface |> save_webp("codec-roundtrip-alpha-lossy.webp",WebpOptions(quality=90.0)) |> skia_try
        var alpha_lossy <- surface |> encode_webp(WebpOptions(quality=90.0)) |> skia_try
        let al : SkImage? = with_image_bytes(alpha_lossy) |> skia_use
        decoded_pixel(al,int2(20),0x80ff4000u,5) |> skia_try
        var black <- surface |> encode_jpeg(JpegOptions(quality=100,downsample=SkiaJpegDownsample.YUV444,alpha=SkiaJpegAlpha.BlendOnBlack)) |> skia_try
        let b : SkImage? = with_image_bytes(black) |> skia_use
        decoded_pixel(b,int2(20),0xff802000u,3) |> skia_try
        let external_jpeg : SkImage? = with_image_file("assets/images/fixture-quadrants.jpg") |> skia_use
        let external_webp : SkImage? = with_image_file("assets/images/fixture-alpha.webp") |> skia_use
        decoded_pixel(external_jpeg,int2(4,4),0xff39b5f0u,3) |> skia_try
        decoded_pixel(external_webp,int2(24,4),0x80ff4000u,0) |> skia_try
        decoded_pixel(external_webp,int2(24,20),0u,0) |> skia_try
        var invalid <- array<uint8>(1,2,3)
        var empty : array<uint8>
        check_codec(is_err(image_from_bytes(invalid)) && is_err(image_from_bytes(empty)),"invalid/empty encoded header rejected") |> skia_try
        check_codec(is_err(encode_jpeg(surface,JpegOptions(quality=-1))) && is_err(encode_jpeg(surface,JpegOptions(quality=101))),"JPEG quality bounds") |> skia_try
        check_codec(is_err(encode_webp(surface,WebpOptions(quality=sqrt(-1.0)))) && is_err(encode_webp(surface,WebpOptions(quality=101.0))),"WebP finite quality bounds") |> skia_try
        check_codec(!Skia_EncodeJpeg(surface,101,SkiaJpegDownsample.YUV444,SkiaJpegAlpha.Ignore,invalid) && length(invalid)==3 && invalid[0]==1,"failed encoding preserves output array") |> skia_try
        check_codec(is_err(encode_png(null)) && is_err(save_jpeg(surface,"codec-missing-directory/output.jpg")),"null surface / output failure") |> skia_try
        var loaded=load_image("assets/images/fixture-quadrants.jpg") |> skia_try
        {
            defer() {Skia_ImageUnref(loaded)}
            decoded_pixel(loaded,int2(4,4),0xff39b5f0u,3) |> skia_try
        }
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=codec_tests()
    if (is_err(result)) {let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return 1}
    print("PASS codecs: JPEG/WebP file+bytes, lossy/lossless/alpha, independent fixtures, copied ownership and errors\n")
    return 0
}
