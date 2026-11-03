#pragma once
#include "skia_api.h"
#include "skia_web_lifecycle.h"
#include "daScript/daScript.h"
#include <SDL3/SDL.h>
#include "include/gpu/ganesh/GrBackendSurface.h"
#include "include/gpu/ganesh/GrDirectContext.h"
#include "include/gpu/ganesh/SkSurfaceGanesh.h"
#include "include/gpu/ganesh/gl/GrGLAssembleInterface.h"
#include "include/gpu/ganesh/gl/GrGLBackendSurface.h"
#include "include/gpu/ganesh/gl/GrGLDirectContext.h"
#include <memory>
#include <string>
#ifdef __EMSCRIPTEN__
#include <emscripten/html5_webgl.h>
#endif

struct SkiaWindow {
    SDL_Window* window=nullptr;
    SDL_GLContext gl=nullptr;
    sk_sp<GrDirectContext> context;
    sk_sp<SkSurface> surface;
    int width=0,height=0;
    bool closed=false,video=false,ownsSDL=true;
    uint32_t generation=0;
#ifdef __EMSCRIPTEN__
    bool observing=false;
    int webGeneration=0;
#endif
    ~SkiaWindow() {
        if(gl && window && !SDL_GL_MakeCurrent(window,gl) && context) context->abandonContext();
#ifdef __EMSCRIPTEN__
        if(context && emscripten_is_webgl_context_lost(emscripten_webgl_get_current_context())) context->abandonContext();
#endif
        surface.reset(); context.reset();
#ifdef __EMSCRIPTEN__
        if(observing) Skia_WebObserve(int(reinterpret_cast<intptr_t>(gl)),-1);
#endif
        if(ownsSDL && gl) SDL_GL_DestroyContext(gl);
        if(ownsSDL && window) SDL_DestroyWindow(window);
        if(video) SDL_QuitSubSystem(SDL_INIT_VIDEO);
    }
};
inline thread_local std::string skia_sdl_error;
inline char* Skia_WindowError(das::Context* context,das::LineInfoArg* at) {
    return context->allocateString(skia_sdl_error.c_str(),uint32_t(skia_sdl_error.size()),at);
}
inline bool Skia_SdlFailure() { skia_sdl_error=SDL_GetError(); return false; }
inline GrGLFuncPtr Skia_GLProc(void*,const char* name) {
    return reinterpret_cast<GrGLFuncPtr>(SDL_GL_GetProcAddress(name));
}
// Invalidating Ganesh must precede releasing its surface on a lost context.
inline void Skia_AbandonWindowContext(SkiaWindow* p) {
    if(p->context) p->context->abandonContext();
    p->surface.reset();p->context.reset();p->width=p->height=0;
}
inline sk_sp<const GrGLInterface> Skia_CreateWindowContext(SkiaWindow* p) {
#ifdef __EMSCRIPTEN__
    auto api=GrGLMakeAssembledWebGLInterface(nullptr,Skia_GLProc);
#else
    auto api=GrGLMakeAssembledInterface(nullptr,Skia_GLProc);
#endif
    if(!api) {skia_sdl_error="Cannot assemble Skia GL interface";return nullptr;}
    p->context=GrDirectContexts::MakeGL(api);
    if(!p->context) {skia_sdl_error="Cannot create Skia Ganesh context";return nullptr;}
    ++p->generation;
    return api;
}
inline bool Skia_ObserveWindowContext(SkiaWindow* p) {
#ifdef __EMSCRIPTEN__
    int handle=int(reinterpret_cast<intptr_t>(p->gl));
    if(!Skia_WebObserve(handle,1)) {skia_sdl_error="Cannot observe host WebGL context";return false;}
    p->observing=true;p->webGeneration=Skia_WebContextState(handle);
#endif
    return true;
}
inline bool Skia_WindowContextCurrent(SkiaWindow* p) {
#ifdef __EMSCRIPTEN__
    int state=Skia_WebContextState(int(reinterpret_cast<intptr_t>(p->gl)));
    if(state<0 || state!=p->webGeneration) Skia_AbandonWindowContext(p);
    if(state<0) {skia_sdl_error="WebGL context temporarily lost";return false;}
    p->webGeneration=state;
#endif
    if(!SDL_GL_MakeCurrent(p->window,p->gl)) return Skia_SdlFailure();
    return true;
}
// -1 error, 0 temporarily unavailable, 1 drawable. Never polls host events.
inline int Skia_PrepareWindowFrame(SkiaWindow* p) {
#ifdef __EMSCRIPTEN__
    if(Skia_WebContextState(int(reinterpret_cast<intptr_t>(p->gl)))<0) {
        Skia_AbandonWindowContext(p);return 0;
    }
#endif
    if(!Skia_WindowContextCurrent(p)) return -1;
    int w=0,h=0;
    if(!SDL_GetWindowSizeInPixels(p->window,&w,&h)) {Skia_SdlFailure();return -1;}
    if((SDL_GetWindowFlags(p->window)&SDL_WINDOW_MINIMIZED) || w<=0 || h<=0) {
        p->surface.reset();p->width=p->height=0;
#ifndef __EMSCRIPTEN__
        SDL_Delay(16); // Avoid spinning the native event loop while minimized.
#endif
        return 0;
    }
    if(!p->context && !Skia_CreateWindowContext(p)) return -1;
    return 1;
}
inline uint32_t Skia_WindowContextGeneration(const SkiaWindow* p) {return p->generation;}
inline SkiaWindow* Skia_NewWindow(const char* title,int width,int height,bool hidden) {
    if(width<=0 || height<=0) { skia_sdl_error="Window dimensions must be positive"; return nullptr; }
    auto p=std::make_unique<SkiaWindow>();
    if(!SDL_InitSubSystem(SDL_INIT_VIDEO)) { Skia_SdlFailure(); return nullptr; }
    p->video=true;
#ifdef __EMSCRIPTEN__
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,0);
#else
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,3);
#endif
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,1);
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE,8); SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE,8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE,8); SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE,8);
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE,8);
    p->window=SDL_CreateWindow(title,width,height,SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE|SDL_WINDOW_HIGH_PIXEL_DENSITY|(hidden?SDL_WINDOW_HIDDEN:0));
    if(!p->window) { Skia_SdlFailure(); return nullptr; }
    p->gl=SDL_GL_CreateContext(p->window);
    if(!p->gl) { Skia_SdlFailure(); return nullptr; }
    if(!SDL_GL_MakeCurrent(p->window,p->gl)) { Skia_SdlFailure(); return nullptr; }
    if(!Skia_ObserveWindowContext(p.get()) || !Skia_CreateWindowContext(p.get())) return nullptr;
    SDL_GL_SetSwapInterval(1);
    return p.release();
}
inline void Skia_DeleteWindow(SkiaWindow* p) { delete p; }
inline SkCanvas* Skia_BeginFrame(SkiaWindow* p) {
    int ready=Skia_PrepareWindowFrame(p);
    if(ready<=0) {
        if(ready==0) skia_sdl_error="Frame temporarily unavailable; call prepare_frame before drawing";
        return nullptr;
    }
    int w=0,h=0;
    if(!SDL_GetWindowSizeInPixels(p->window,&w,&h)) { Skia_SdlFailure(); return nullptr; }
    if(w<=0 || h<=0) { skia_sdl_error="Window has no drawable pixels"; return nullptr; }
    if(!p->surface || p->width!=w || p->height!=h) {
        p->surface.reset();
        int stencil=0,samples=0;
        SDL_GL_GetAttribute(SDL_GL_STENCIL_SIZE,&stencil);
        SDL_GL_GetAttribute(SDL_GL_MULTISAMPLESAMPLES,&samples);
        // This adapter owns the context and draws to its default framebuffer.
        // It does not support an externally changed framebuffer binding.
        GrGLFramebufferInfo fbo{0,0x8058}; // GL_RGBA8
        auto target=GrBackendRenderTargets::MakeGL(w,h,samples,stencil,fbo);
        p->surface=SkSurfaces::WrapBackendRenderTarget(p->context.get(),target,
            kBottomLeft_GrSurfaceOrigin,kRGBA_8888_SkColorType,nullptr,nullptr);
        if(!p->surface) { skia_sdl_error="Cannot wrap window framebuffer"; return nullptr; }
        p->width=w; p->height=h;
    }
    return p->surface->getCanvas();
}
inline bool Skia_Present(SkiaWindow* p) {
    if(!Skia_WindowContextCurrent(p) || !p->context) return false;
    p->context->flushAndSubmit();
    if(!SDL_GL_SwapWindow(p->window)) return Skia_SdlFailure();
    return true;
}
inline bool Skia_PollWindow(SkiaWindow* p) {
    SDL_Event e;
    while(SDL_PollEvent(&e)) {
        if(e.type==SDL_EVENT_QUIT || (e.type==SDL_EVENT_WINDOW_CLOSE_REQUESTED && e.window.windowID==SDL_GetWindowID(p->window)) ||
           (e.type==SDL_EVENT_KEY_DOWN && e.key.key==SDLK_ESCAPE)) p->closed=true;
    }
    return !p->closed;
}
inline bool Skia_ResizeWindow(SkiaWindow* p,int w,int h) {
    if(!SDL_SetWindowSize(p->window,w,h)) return Skia_SdlFailure();
    return true;
}
inline bool Skia_ReadWindowPixel(SkiaWindow* p,int x,int y,uint32_t& color) {
    if(!p->surface) return false;
    bool ok=Skia_ReadPixel(p->surface.get(),x,y,color);
    if(!ok) {
        skia_sdl_error="Readback failed: surface="+std::to_string(p->surface->width())+"x"+std::to_string(p->surface->height())+
            "; window="+std::to_string(p->width)+"x"+std::to_string(p->height)+"; coordinate="+std::to_string(x)+","+std::to_string(y);
    }
    return ok;
}
