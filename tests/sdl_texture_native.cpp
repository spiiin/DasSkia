#include "skia_sdl3_aot.h"
#include <vector>
#include <iostream>
static bool pixel(SDL_Surface* s,int x,int y,int r,int g,int b) {
    Uint8 rr=0,gg=0,bb=0,aa=0;
    return SDL_ReadSurfacePixel(s,x,y,&rr,&gg,&bb,&aa) && abs(int(rr)-r)<=2 && abs(int(gg)-g)<=2 && abs(int(bb)-b)<=2;
}
int main() {
    if(!SDL_Init(SDL_INIT_VIDEO)) return 1;
    auto output=SDL_CreateSurface(64,48,SDL_PIXELFORMAT_RGBA32);
    auto renderer=output?SDL_CreateSoftwareRenderer(output):nullptr;
    auto texture=renderer?Skia_NewSDLTexture(renderer,13,9):nullptr;
    int result=1;
    if(texture) {
        // CPU source rows deliberately have padding, unlike the upload texture.
        std::vector<uint8_t> storage(64*9,0x7b);
        auto raster=SkSurfaces::WrapPixels(SkImageInfo::Make(13,9,kRGBA_8888_SkColorType,kPremul_SkAlphaType),storage.data(),64);
        if(raster) do {
            auto c=raster->getCanvas();c->clear(0);SkPaint p;p.setBlendMode(SkBlendMode::kSrc);
            p.setColor(0xff39b5f0);c->drawRect(SkRect::MakeXYWH(1,1,4,4),p);
            p.setColor(0x80ff4000);c->drawRect(SkRect::MakeXYWH(7,0,6,9),p);
            SDL_SetRenderDrawColor(renderer,11,22,33,255);
            if(!Skia_UploadSDLTexture(texture,raster.get())) break;
            Uint8 r=0,g=0,b=0,a=0;
            if(!SDL_GetRenderDrawColor(renderer,&r,&g,&b,&a) || r!=11 || g!=22 || b!=33 || a!=255) break;
            auto original=Skia_GetSDLTexture(texture);
            if(Skia_ResizeSDLTexture(texture,0,3) || Skia_GetSDLTexture(texture)!=original) break;
            if(!SDL_SetRenderDrawColor(renderer,0,0,255,255) || !SDL_RenderClear(renderer) ||
               !SDL_RenderTexture(renderer,original,nullptr,nullptr) || !SDL_RenderPresent(renderer)) break;
            if(!pixel(output,0,0,0,0,255) || !pixel(output,12,12,57,181,240) || !pixel(output,60,24,128,32,127)) break;
            Skia_DeleteSDLTexture(texture);texture=nullptr;
            if(!SDL_RenderClear(renderer) || !SDL_RenderPresent(renderer)) break;
            result=0;
        } while(false);
    }
    Skia_DeleteSDLTexture(texture);
    if(renderer) SDL_DestroyRenderer(renderer);
    if(output) SDL_DestroySurface(output);
    SDL_Quit();
    if(result) std::cerr << "FAIL SDL texture software/pitch/alpha: " << skia_sdl_error << "\n";
    else std::cout << "PASS software SDL_Renderer: padded raster rows, alpha/RGBA pixels, renderer state and borrowed lifetime\n";
    return result;
}
