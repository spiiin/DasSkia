#include "skia_sdl3_aot.h"
#include <iostream>
int main() {
    if(!SDL_Init(SDL_INIT_VIDEO) || !Skia_ConfigureSDLGL()) return 1;
    auto window=SDL_CreateWindow("Interop native",120,80,SDL_WINDOW_OPENGL|SDL_WINDOW_HIDDEN|SDL_WINDOW_RESIZABLE);
    auto gl=window?SDL_GL_CreateContext(window):nullptr;
    auto target=gl?Skia_AttachSDLWindow(window,gl):nullptr;
    int result=1;
    if(target) {
        do {
            GrGLuint fbo=0;target->api->fFunctions.fGenFramebuffers(1,&fbo);
            target->api->fFunctions.fBindFramebuffer(0x8D40,fbo);
            if(Skia_BeginSDLFrame(target)) break;
            target->api->fFunctions.fBindFramebuffer(0x8D40,0);
            target->api->fFunctions.fDeleteFramebuffers(1,&fbo);
            if(!SDL_SetWindowSize(window,240,160)) break;
            SDL_PumpEvents();
            auto canvas=Skia_BeginSDLFrame(target);if(!canvas) break;
            int w=0,h=0;
            if(!Skia_SDLFrameSize(target,w,h) || w!=240 || h!=160) break;
            canvas->clear(0xff50d99a);
            uint32_t color=0;
            if(!Skia_ReadSDLFramePixel(target,230,150,color) || color!=0xff50d99a || !Skia_EndSDLFrame(target)) break;
            target->api->fFunctions.fEnable(0x0C11);
            target->api->fFunctions.fScissor(0,0,1,1);
            canvas=Skia_BeginSDLFrame(target);if(!canvas) break;
            canvas->clear(0xff39b5f0);
            if(!Skia_ReadSDLFramePixel(target,230,150,color) || color!=0xff39b5f0 || !Skia_EndSDLFrame(target)) break;
            result=0;
        } while(false);
        Skia_DetachSDLWindow(target);
        if(!SDL_GL_MakeCurrent(window,gl)) result=1;
    }
    if(gl) SDL_GL_DestroyContext(gl);
    if(window) SDL_DestroyWindow(window);
    SDL_Quit();
    if(result) std::cerr<<"FAIL interop native: "<<skia_sdl_error<<"\n";
    else std::cout<<"PASS interop native: default FBO guard, resize, external GL state, borrowed lifetime\n";
    return result;
}
