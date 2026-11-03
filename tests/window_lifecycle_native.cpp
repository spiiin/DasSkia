#include "skia_aot.h"
#include <iostream>
static bool wait_minimized(SDL_Window* w,bool expected) {
    auto until=SDL_GetTicks()+3000;
    do {SDL_PumpEvents();if(bool(SDL_GetWindowFlags(w)&SDL_WINDOW_MINIMIZED)==expected)return true;SDL_Delay(5);} while(SDL_GetTicks()<until);
    return false;
}
int main() {
    auto p=Skia_NewWindow("dasSkia lifecycle test",128,96,false);
    if(!p) return 1;
    int result=1;
    do {
        if(Skia_PrepareWindowFrame(p)!=1 || Skia_WindowContextGeneration(p)!=1) break;
        auto c=Skia_BeginFrame(p);if(!c) break;
        c->clear(0xff39b5f0);if(!Skia_Present(p)) break;
        if(!SDL_MinimizeWindow(p->window) || !wait_minimized(p->window,true)) break;
        if(Skia_PrepareWindowFrame(p)!=0 || p->surface) break;
        if(!SDL_RestoreWindow(p->window) || !wait_minimized(p->window,false)) break;
        if(!Skia_ResizeWindow(p,180,120)) break;
        SDL_PumpEvents();
        if(Skia_PrepareWindowFrame(p)!=1 || Skia_WindowContextGeneration(p)!=1) break;
        c=Skia_BeginFrame(p);if(!c || p->width!=180 || p->height!=120) break;
        c->clear(0xff50d99a);uint32_t color=0;
        if(!Skia_ReadWindowPixel(p,170,110,color) || color!=0xff50d99a || !Skia_Present(p)) break;
        result=0;
    } while(false);
    Skia_DeleteWindow(p);
    if(result) std::cerr << "FAIL minimize/restore/resize: " << skia_sdl_error << "\n";
    else std::cout << "PASS minimize skips frame; restore/resize redraw pixels; GL generation preserved\n";
    return result;
}
