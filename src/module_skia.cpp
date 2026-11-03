#include "skia_aot.h"
#include "skia_paragraph_registration.h"
#include "skia_codecs_registration.h"
#include "skia_drawing_registration.h"
#include "skia_picture_registration.h"
#include "skia_geometry_registration.h"
#include "skia_effects_registration.h"
#include "skia_runtime_registration.h"
#include "skia_filter_graph_registration.h"
#include "skia_advanced_filters_registration.h"
namespace das {
class Module_dasSkia : public Module {
public:
    Module_dasSkia() : Module("skia") {
        ModuleLibrary lib(this); lib.addBuiltInModule();
#ifdef __EMSCRIPTEN__
        addConstant(*this,"SKIA_WEB",true);
#else
        addConstant(*this,"SKIA_WEB",false);
#endif
#define TYPE(T) addAnnotation(new DummyTypeAnnotation(#T,#T,sizeof(T),alignof(T)))
        TYPE(SkSurface); TYPE(SkCanvas); TYPE(SkPaint); TYPE(SkPath); TYPE(SkImage);
        TYPE(SkFont); TYPE(SkiaText);
#ifdef DASSKIA_WITH_SDL
        TYPE(SkiaWindow);
#endif
#undef TYPE
        registerDrawing(*this,lib);
        registerCodecs(*this,lib);
        registerGeometry(*this,lib);
        registerEffects(*this,lib);
        registerRuntime(*this,lib);
        registerPicture(*this,lib);
        registerFilterGraph(*this,lib);
        registerAdvancedFilters(*this,lib);
        registerParagraph(*this,lib);
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(*this,lib,#F,SideEffects::worstDefault,#F)
        BIND(Skia_NewRaster); BIND(Skia_SurfaceUnref); BIND(Skia_GetCanvas);
        BIND(Skia_SurfaceWidth); BIND(Skia_SurfaceHeight);
        BIND(Skia_NewPaint); BIND(Skia_DeletePaint); BIND(Skia_SetColor);
        BIND(Skia_SetAntialias); BIND(Skia_SetStroke);
        BIND(Skia_NewPath); BIND(Skia_DeletePath); BIND(Skia_PathMoveTo);
        BIND(Skia_PathLineTo); BIND(Skia_PathCubicTo); BIND(Skia_PathClose); BIND(Skia_PathReset);
        BIND(Skia_Clear); BIND(Skia_DrawRect); BIND(Skia_DrawCircle);
        BIND(Skia_DrawPath); BIND(Skia_DrawImage); BIND(Skia_Save);
        BIND(Skia_SaveCount); BIND(Skia_RestoreToCount); BIND(Skia_Translate);
        BIND(Skia_Scale); BIND(Skia_Rotate); BIND(Skia_ClipRect);
        BIND(Skia_Snapshot); BIND(Skia_LoadImage); BIND(Skia_ImageUnref);
        BIND(Skia_SavePng); BIND(Skia_ReadPixel);
        BIND(Skia_LoadFont); BIND(Skia_DeleteFont); BIND(Skia_FontMetrics); BIND(Skia_TextError);
        BIND(Skia_ShapeText); BIND(Skia_DeleteText); BIND(Skia_DrawText);
        BIND(Skia_TextGlyphCount); BIND(Skia_TextLineCount); BIND(Skia_TextMissingGlyphs);
        BIND(Skia_TextWidth); BIND(Skia_TextHeight); BIND(Skia_TextGlyph);
#ifdef DASSKIA_WITH_SDL
        BIND(Skia_NewWindow); BIND(Skia_DeleteWindow); BIND(Skia_WindowError);
        BIND(Skia_PrepareWindowFrame); BIND(Skia_WindowContextGeneration); BIND(Skia_BeginFrame); BIND(Skia_Present); BIND(Skia_PollWindow);
        BIND(Skia_ResizeWindow); BIND(Skia_ReadWindowPixel);
#endif
#undef BIND
        verifyAotReady();
    }
    ModuleAotType aotRequire(TextWriter& out) const override {
        out << "#include \"skia_aot.h\"\n"; return ModuleAotType::cpp;
    }
};
}
REGISTER_MODULE_IN_NAMESPACE(Module_dasSkia,das);
