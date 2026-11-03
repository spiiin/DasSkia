#pragma once
#include <cstring>
#include <memory>
// Included after the real dasSDL3 type factories in skia_sdl3_aot.h.
struct SkiaSDLTexture {
    SDL_Renderer* renderer=nullptr; // borrowed; must outlive this object
    SDL_Texture* texture=nullptr;
    int width=0,height=0;
    ~SkiaSDLTexture() {if(texture) SDL_DestroyTexture(texture);}
};
inline SDL_Texture* Skia_CreateUploadTexture(SDL_Renderer* renderer,int w,int h) {
    if(!renderer || w<=0 || h<=0 || w>16384 || h>16384) {
        skia_sdl_error="SDL texture requires a renderer and dimensions in 1..16384";return nullptr;
    }
    auto texture=SDL_CreateTexture(renderer,SDL_PIXELFORMAT_RGBA32,SDL_TEXTUREACCESS_STREAMING,w,h);
    if(!texture) {Skia_SdlFailure();return nullptr;}
    if(!SDL_SetTextureBlendMode(texture,SDL_BLENDMODE_BLEND) || !SDL_SetTextureScaleMode(texture,SDL_SCALEMODE_NEAREST)) {
        Skia_SdlFailure();SDL_DestroyTexture(texture);return nullptr;
    }
    // A newly created/resized texture starts as transparent black.
    void* data=nullptr;int pitch=0;
    if(!SDL_LockTexture(texture,nullptr,&data,&pitch)) {Skia_SdlFailure();SDL_DestroyTexture(texture);return nullptr;}
    bool valid=data && pitch>=w*4;
    if(valid) for(int y=0;y<h;++y) std::memset(static_cast<uint8_t*>(data)+size_t(y)*pitch,0,size_t(w)*4);
    SDL_UnlockTexture(texture);
    if(!valid) {skia_sdl_error="Invalid SDL texture lock pitch";SDL_DestroyTexture(texture);return nullptr;}
    return texture;
}
inline SkiaSDLTexture* Skia_NewSDLTexture(SDL_Renderer* renderer,int w,int h) {
    auto p=std::make_unique<SkiaSDLTexture>();p->renderer=renderer;
    p->texture=Skia_CreateUploadTexture(renderer,w,h);
    if(!p->texture) return nullptr;
    p->width=w;p->height=h;return p.release();
}
inline void Skia_DeleteSDLTexture(SkiaSDLTexture* p) {delete p;}
inline bool Skia_ResizeSDLTexture(SkiaSDLTexture* p,int w,int h) {
    if(!p) {skia_sdl_error="Null SDL texture adapter";return false;}
    if(w==p->width && h==p->height) return true;
    auto replacement=Skia_CreateUploadTexture(p->renderer,w,h);
    if(!replacement) return false;
    SDL_DestroyTexture(p->texture);p->texture=replacement;p->width=w;p->height=h;
    return true;
}
inline SDL_Texture* Skia_GetSDLTexture(SkiaSDLTexture* p) {return p?p->texture:nullptr;}
inline bool Skia_SDLTextureSize(const SkiaSDLTexture* p,int& w,int& h) {
    w=h=0;if(!p) {skia_sdl_error="Null SDL texture adapter";return false;}
    w=p->width;h=p->height;return true;
}
inline bool Skia_UploadSDLTexture(SkiaSDLTexture* p,SkSurface* surface) {
    if(!p || !surface) {skia_sdl_error="Upload requires a texture adapter and raster surface";return false;}
    SkPixmap source;
    if(!surface->peekPixels(&source)) {skia_sdl_error="Upload requires CPU-addressable raster pixels";return false;}
    if(source.width()!=p->width || source.height()!=p->height) {
        skia_sdl_error="Raster surface and SDL texture dimensions must match";return false;
    }
    void* data=nullptr;int pitch=0;
    if(!SDL_LockTexture(p->texture,nullptr,&data,&pitch)) return Skia_SdlFailure();
    // Skia converts into the actual SDL row pitch. RGBA32 is byte RGBA on both
    // architectures; unpremultiplication matches SDL's standard alpha blend.
    bool valid=data && pitch>=p->width*4;
    bool ok=valid && source.readPixels(SkImageInfo::Make(p->width,p->height,kRGBA_8888_SkColorType,kUnpremul_SkAlphaType),data,size_t(pitch));
    SDL_UnlockTexture(p->texture);
    if(!ok) skia_sdl_error=valid?"Cannot convert raster pixels to unpremultiplied RGBA":"Invalid SDL texture lock pitch";
    return ok;
}
MAKE_TYPE_FACTORY(SkiaSDLTexture,SkiaSDLTexture);
