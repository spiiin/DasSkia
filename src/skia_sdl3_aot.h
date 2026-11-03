#pragma once
#include "skia_aot.h"
#ifdef __EMSCRIPTEN__
#include "sdl3_web_aot.h"
#else
#include "sdl3_aot.h"
#endif

struct SkiaSDLTarget {
    SkiaWindow frame;
    sk_sp<const GrGLInterface> api;
    bool active=false;
    uint32_t apiGeneration=0;
    SkiaSDLTarget() { frame.ownsSDL=false; }
};
inline bool Skia_ConfigureSDLGL() {
#ifdef __EMSCRIPTEN__
    const int profile=SDL_GL_CONTEXT_PROFILE_ES,major=3,minor=0;
#else
    const int profile=SDL_GL_CONTEXT_PROFILE_CORE,major=3,minor=3;
#endif
    if(!SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,profile) || !SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,major) ||
       !SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,minor) || !SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,1) ||
       !SDL_GL_SetAttribute(SDL_GL_RED_SIZE,8) || !SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,8) ||
       !SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,8) || !SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,8) || !SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE,8)) return Skia_SdlFailure();
    return true;
}
inline bool Skia_SDLTargetCurrent(SkiaSDLTarget* p) {
    return Skia_WindowContextCurrent(&p->frame);
}
inline int Skia_PrepareSDLFrame(SkiaSDLTarget* p) {
    if(p->active) {skia_sdl_error="Cannot prepare during an active SDL frame";return -1;}
    int ready=Skia_PrepareWindowFrame(&p->frame);
    if(ready==1 && (!p->api || p->apiGeneration!=p->frame.generation)) {
#ifdef __EMSCRIPTEN__
        p->api=GrGLMakeAssembledWebGLInterface(nullptr,Skia_GLProc);
#else
        p->api=GrGLMakeAssembledInterface(nullptr,Skia_GLProc);
#endif
        if(!p->api) {skia_sdl_error="Cannot assemble restored host GL interface";return -1;}
        p->apiGeneration=p->frame.generation;
    }
    return ready;
}
inline uint32_t Skia_SDLContextGeneration(const SkiaSDLTarget* p) {return p->frame.generation;}

inline SkiaSDLTarget* Skia_AttachSDLWindow(SDL_Window* window,SDL_GLContextState* gl) {
    if(!window || !gl || !(SDL_WasInit(SDL_INIT_VIDEO)&SDL_INIT_VIDEO)) { skia_sdl_error="Attach requires a live SDL OpenGL window/context and initialized video";return nullptr; }
    if(!(SDL_GetWindowFlags(window)&SDL_WINDOW_OPENGL) || SDL_GetRenderer(window)) { skia_sdl_error="Attach requires an OpenGL window without an SDL_Renderer";return nullptr; }
    auto p=std::make_unique<SkiaSDLTarget>();p->frame.window=window;p->frame.gl=gl;
    if(!SDL_GL_MakeCurrent(window,gl)) { Skia_SdlFailure();return nullptr; }
    if(!Skia_ObserveWindowContext(&p->frame)) return nullptr;
    p->api=Skia_CreateWindowContext(&p->frame);
    if(!p->api) return nullptr;
    p->apiGeneration=p->frame.generation;
    return p.release();
}
inline void Skia_DetachSDLWindow(SkiaSDLTarget* p) { delete p; }
inline SkCanvas* Skia_BeginSDLFrame(SkiaSDLTarget* p) {
    if(p->active) { skia_sdl_error="SDL frame is already active";return nullptr; }
    int ready=Skia_PrepareSDLFrame(p);
    if(ready<=0) {if(ready==0) skia_sdl_error="SDL frame temporarily unavailable; call prepare_sdl_frame before drawing";return nullptr;}
    GrGLint framebuffer=0;p->api->fFunctions.fGetIntegerv(0x8CA6,&framebuffer);
    if(framebuffer!=0) { skia_sdl_error="Bind host default framebuffer 0 before beginning Skia frame";return nullptr; }
    p->frame.context->resetContext(); // external GL may have changed cached state
    auto canvas=Skia_BeginFrame(&p->frame);
    if(canvas) p->active=true;
    return canvas;
}
inline bool Skia_EndSDLFrame(SkiaSDLTarget* p) {
    if(!p->active) { skia_sdl_error="No active SDL frame";return false; }
    p->active=false;
    if(!Skia_SDLTargetCurrent(p) || !p->frame.context) return false;
    p->frame.context->flushAndSubmit();
    return true; // swap belongs to the host
}
inline bool Skia_SDLFrameSize(SkiaSDLTarget* p,int& w,int& h) {
    if(!SDL_GetWindowSizeInPixels(p->frame.window,&w,&h)) return Skia_SdlFailure();
    return true;
}
inline bool Skia_ReadSDLFramePixel(SkiaSDLTarget* p,int x,int y,uint32_t& color) {
    if(!p->active) { skia_sdl_error="Read pixels inside an active SDL frame";return false; }
    return Skia_ReadWindowPixel(&p->frame,x,y,color);
}
MAKE_TYPE_FACTORY(SkiaSDLTarget,SkiaSDLTarget);

#include "skia_sdl_texture.h"
