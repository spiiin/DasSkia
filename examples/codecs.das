options gen2
require dasskia/skia_codecs
require dasskia/skia_text
require dasskia/skia_sdl_gl
require dasskia/skia_scope
var window : SkiaWindow?
var paint : SkPaint?
var images : array<SkImage?>
var labels : array<SkiaText?>
var title : SkiaText?
var frames : int

def start_codecs() : SkiaStatus {
    window=create_window(SkiaWindowOptions(title="dasSkia · JPEG and WebP",size=int2(900,640))) |> skia_try
    paint=create_paint(PaintOptions(color=0xffe8edf8u))
    resize(images,6);resize(labels,6)
    let fonts_result=with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions(size=19.0)) $(font : SkFont?) {
        title=shape_text(font,"PNG, JPEG and WebP · one API on desktop and web",TextOptions()) |> skia_try
        var names <- array("Original / PNG","JPEG q35 / 4:2:0","JPEG q95 / 4:4:4","WebP lossy q50","WebP lossless / alpha","Independent WebP fixture")
        for (i in range(length(names))) {
            var shaped=shape_text(font,names[i],TextOptions()) |> skia_try
            labels[i]=shaped
        }
        return skia_ok()
    }
    fonts_result |> skia_try
    return with_raster_surface(RasterSurfaceOptions(size=int2(256,160))) $(surface : SkSurface?) {
        let c=canvas(surface)
        for (y in range(160)) {
            Skia_SetColor(paint,argb8(255u,uint(25+y),uint(170-y/2),uint(220-y)))
            c |> draw_rect(float4(0.0,float(y),256.0,1.0),paint)
        }
        Skia_SetColor(paint,0xff39b5f0u);c |> draw_rect(float4(16.0,16.0,80.0,80.0),paint)
        for (y in range(8)) {for (x in range(8)) {
            var color=0xffff6030u
            if ((x+y)%2!=0) {color=0xff2450d0u}
            Skia_SetColor(paint,color)
            c |> draw_rect(float4(128.0+float(x)*16.0,float(y)*16.0,16.0,16.0),paint)
        }}
        Skia_SetBlendMode(paint,SkBlendMode.Src)
        Skia_SetColor(paint,0x80ff4000u);c |> draw_rect(float4(0.0,140.0,120.0,20.0),paint)
        Skia_SetColor(paint,0u);c |> draw_rect(float4(120.0,140.0,136.0,20.0),paint)
        Skia_SetBlendMode(paint,SkBlendMode.SrcOver)
        var original <- surface |> encode_png() |> skia_try
        var low <- surface |> encode_jpeg(JpegOptions(quality=35,alpha=SkiaJpegAlpha.BlendOnBlack)) |> skia_try
        var high <- surface |> encode_jpeg(JpegOptions(quality=95,downsample=SkiaJpegDownsample.YUV444,alpha=SkiaJpegAlpha.BlendOnBlack)) |> skia_try
        var lossy <- surface |> encode_webp(WebpOptions(quality=50.0)) |> skia_try
        var lossless <- surface |> encode_webp(WebpOptions(quality=75.0,compression=SkiaWebpCompression.Lossless)) |> skia_try
        var decoded_0=image_from_bytes(original) |> skia_try
        images[0]=decoded_0
        var decoded_1=image_from_bytes(low) |> skia_try
        images[1]=decoded_1
        var decoded_2=image_from_bytes(high) |> skia_try
        images[2]=decoded_2
        var decoded_3=image_from_bytes(lossy) |> skia_try
        images[3]=decoded_3
        var decoded_4=image_from_bytes(lossless) |> skia_try
        images[4]=decoded_4
        var decoded_5=load_image("assets/images/fixture-alpha.webp") |> skia_try
        images[5]=decoded_5
        surface |> save_jpeg("codec-example.jpg",JpegOptions(quality=95,downsample=SkiaJpegDownsample.YUV444,alpha=SkiaJpegAlpha.BlendOnBlack)) |> skia_try
        surface |> save_webp("codec-example.webp",WebpOptions(compression=SkiaWebpCompression.Lossless)) |> skia_try
        print("CODEC_BYTES PNG={length(original)} JPEG35={length(low)} JPEG95={length(high)} WEBP_LOSSY={length(lossy)} WEBP_LOSSLESS={length(lossless)}\n")
        return skia_ok()
    }
}
def report_codecs(result : SkiaStatus) : int {
    if (is_err(result)) {let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return -1}
    return 0
}
[export]
def app_init() : int {return report_codecs(start_codecs())}
[export]
def app_frame() : int {
    if (!poll_window(window)) {return 1}
    let ready=prepare_frame(window)
    if (is_err(ready)) {let e=unwrap_err(ready);print("FAIL {e.message}\n");return -1}
    if (!unwrap(ready)) {return 0}
    let result=window |> with_frame() $(c : SkCanvas?) {
        c |> clear(0xff181c28u)
        Skia_SetColor(paint,0xffe8edf8u);c |> draw_text(title,float2(30.0,24.0),paint)
        for (i in range(6)) {
            let left=30.0+float(i%3)*292.0
            let top=110.0+float(i/3)*250.0
            Skia_SetColor(paint,0xffe8edf8u);c |> draw_text(labels[i],float2(left,top-30.0),paint)
            for (y in range(10)) {for (x in range(16)) {
                var color=0xff343b4bu
                if ((x+y)%2!=0) {color=0xff626c80u}
                Skia_SetColor(paint,color)
                c |> draw_rect(float4(left+float(x)*16.0,top+float(y)*16.0,16.0,16.0),paint)
            }}
            c |> draw_image_to(images[i],float4(left,top,256.0,160.0))
        }
        return skia_ok()
    }
    frames++
    if (frames==3) {print("PASS codecs frame 3; PNG/JPEG/WebP decoded gallery\n")}
    return report_codecs(result)
}
[export]
def app_quit() {
    for (image in images) {Skia_ImageUnref(image)};clear(images)
    for (shaped in labels) {destroy_text(shaped)};clear(labels)
    destroy_text(title);title=null
    Skia_DeletePaint(paint);paint=null
    destroy_window(window);window=null
}
