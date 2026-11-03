options gen2
require daslib/defer
module skia_codecs shared public
require dasskia/skia_drawing public
struct JpegOptions {
    quality : int = 100
    downsample : SkiaJpegDownsample = SkiaJpegDownsample.YUV420
    alpha : SkiaJpegAlpha = SkiaJpegAlpha.Ignore
}
struct WebpOptions {
    quality : float = 100.0
    compression : SkiaWebpCompression = SkiaWebpCompression.Lossy
}
def public save_jpeg(surface : SkSurface?; path : string; settings : JpegOptions = JpegOptions()) : SkiaStatus {
    if (!Skia_SaveJpeg(surface,path,settings.quality,settings.downsample,settings.alpha)) {return err(skia_error("save_jpeg",Skia_CodecError()),type<SkiaUnit>)}
    return skia_ok()
}
def public save_webp(surface : SkSurface?; path : string; settings : WebpOptions = WebpOptions()) : SkiaStatus {
    if (!Skia_SaveWebp(surface,path,settings.quality,settings.compression)) {return err(skia_error("save_webp",Skia_CodecError()),type<SkiaUnit>)}
    return skia_ok()
}
def public encode_jpeg(surface : SkSurface?; settings : JpegOptions = JpegOptions()) {
    var bytes : array<uint8>
    if (!Skia_EncodeJpeg(surface,settings.quality,settings.downsample,settings.alpha,bytes)) {return err(skia_error("encode_jpeg",Skia_CodecError()),type<array<uint8>>)}
    return <- move_ok(bytes,type<SkiaError>)
}
def public encode_webp(surface : SkSurface?; settings : WebpOptions = WebpOptions()) {
    var bytes : array<uint8>
    if (!Skia_EncodeWebp(surface,settings.quality,settings.compression,bytes)) {return err(skia_error("encode_webp",Skia_CodecError()),type<array<uint8>>)}
    return <- move_ok(bytes,type<SkiaError>)
}
def public encode_png(surface : SkSurface?) {
    var bytes : array<uint8>
    if (!Skia_EncodePng(surface,bytes)) {return err(skia_error("encode_png",Skia_CodecError()),type<array<uint8>>)}
    return <- move_ok(bytes,type<SkiaError>)
}
def public image_from_bytes(bytes : array<uint8>) {
    var image=Skia_ImageFromBytes(bytes)
    if (image==null) {return err(skia_error("image_from_bytes",Skia_CodecError()),type<SkImage?>)}
    return <- move_ok(image,type<SkiaError>)
}
def public with_image_bytes(bytes : array<uint8>; blk : block<(image : SkImage?) : $Result<auto(ImageBody);SkiaError>>) {
    var made <- image_from_bytes(bytes)
    if (is_err(made)) {return err(unwrap_err(made),type<ImageBody>)}
    let image=move_unwrap(made)
    var result : $Result<ImageBody;SkiaError>
    {
        defer() {Skia_ImageUnref(image)}
        static_if (typeinfo can_copy(type<$Result<ImageBody;SkiaError>>)) {result=blk(image)} else {result <- blk(image)}
    }
    return <- result
}

// Owned image, same format auto-detection as with_image_file.
def public load_image(path : string) {
    var image=Skia_LoadImage(path)
    if (image==null) {return err(skia_error("load_image","Cannot load or recognize encoded image"),type<SkImage?>)}
    return <- move_ok(image,type<SkiaError>)
}
