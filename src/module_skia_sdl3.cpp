#include "skia_sdl3_aot.h"
namespace das {
class Module_skiaSDL3 : public Module {
    bool initialized=false;
public:
    Module_skiaSDL3():Module("skia_sdl3_native") {}
    bool initDependencies() override {
        if(initialized) return true;
        auto sdl=Module::require("sdl3");auto skia=Module::require("skia");
        if(!sdl || !skia || !sdl->initDependencies() || !skia->initDependencies()) return false;
        initialized=true;
        ModuleLibrary lib(this);lib.addBuiltInModule();lib.addModule(sdl);lib.addModule(skia);
        addAnnotation(new DummyTypeAnnotation("SkiaSDLTexture","SkiaSDLTexture",sizeof(SkiaSDLTexture),alignof(SkiaSDLTexture)));
        addAnnotation(new DummyTypeAnnotation("SkiaSDLTarget","SkiaSDLTarget",sizeof(SkiaSDLTarget),alignof(SkiaSDLTarget)));
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(*this,lib,#F,SideEffects::worstDefault,#F)
        BIND(Skia_ConfigureSDLGL);BIND(Skia_AttachSDLWindow);BIND(Skia_DetachSDLWindow);
        BIND(Skia_PrepareSDLFrame);BIND(Skia_SDLContextGeneration);BIND(Skia_BeginSDLFrame);BIND(Skia_EndSDLFrame);BIND(Skia_SDLFrameSize);BIND(Skia_ReadSDLFramePixel);
        BIND(Skia_NewSDLTexture);BIND(Skia_DeleteSDLTexture);BIND(Skia_ResizeSDLTexture);
        BIND(Skia_GetSDLTexture);BIND(Skia_SDLTextureSize);BIND(Skia_UploadSDLTexture);
#undef BIND
        verifyAotReady();return true;
    }
    ModuleAotType aotRequire(TextWriter& out) const override {out<<"#include \"skia_sdl3_aot.h\"\n";return ModuleAotType::cpp;}
};
}
REGISTER_MODULE_IN_NAMESPACE(Module_skiaSDL3,das);
