options gen2
require daslib/defer
module skia_sdl_texture shared public
require dasskia/skia_sdl3 public

def public create_sdl_texture(renderer : SDL_Renderer?; size : int2) {
    var texture=Skia_NewSDLTexture(renderer,size.x,size.y)
    if (texture==null) {return err(skia_error("create_sdl_texture",Skia_WindowError()),type<SkiaSDLTexture?>)}
    return <- move_ok(texture,type<SkiaError>)
}
def public destroy_sdl_texture(texture : SkiaSDLTexture?) {Skia_DeleteSDLTexture(texture)}
// Borrowed SDL_Texture, invalidated by successful size change or destruction.
def public sdl_texture(texture : SkiaSDLTexture?) : SDL_Texture? {return Skia_GetSDLTexture(texture)}
def public resize_sdl_texture(texture : SkiaSDLTexture?; size : int2) : SkiaStatus {
    if (!Skia_ResizeSDLTexture(texture,size.x,size.y)) {return err(skia_error("resize_sdl_texture",Skia_WindowError()),type<SkiaUnit>)}
    return skia_ok()
}
def public sdl_texture_size(texture : SkiaSDLTexture?) {
    var size : int2
    if (!Skia_SDLTextureSize(texture,size.x,size.y)) {return err(skia_error("sdl_texture_size",Skia_WindowError()),type<int2>)}
    return ok(size,type<SkiaError>)
}
def public upload_sdl_texture(texture : SkiaSDLTexture?; surface : SkSurface?) : SkiaStatus {
    if (!Skia_UploadSDLTexture(texture,surface)) {return err(skia_error("upload_sdl_texture",Skia_WindowError()),type<SkiaUnit>)}
    return skia_ok()
}
def public with_sdl_texture(renderer : SDL_Renderer?; size : int2; blk : block<(texture : SkiaSDLTexture?) : $Result<auto(TextureBody);SkiaError>>) {
    var made <- create_sdl_texture(renderer,size)
    if (is_err(made)) {return err(unwrap_err(made),type<TextureBody>)}
    let texture=move_unwrap(made)
    var result : $Result<TextureBody;SkiaError>
    {
        defer() {destroy_sdl_texture(texture)}
        static_if (typeinfo can_copy(type<$Result<TextureBody;SkiaError>>)) {result=blk(texture)} else {result <- blk(texture)}
    }
    return <- result
}
