#pragma once
namespace das {
inline void registerFilterGraph(Module& module,ModuleLibrary& lib) {
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_RuntimeImageFilter);
    // The pinned typeFactory<const T*> also marks the pointer value const.
    // An input array stores assignable pointers to immutable filters; the array
    // parameter itself stays const. Normalize before registration/mangling.
    addExtern<DAS_BIND_FUN(Skia_RuntimeImageFilterInputs)>(module,lib,"Skia_RuntimeImageFilterInputs",SideEffects::worstDefault,"Skia_RuntimeImageFilterInputs",
        [](auto fn) { fn->arguments[2]->type->firstType->constant=false; });
    BIND(Skia_ImageSourceFilter);
    BIND(Skia_PictureSourceFilter);
    BIND(Skia_ShaderSourceFilter);
    addExtern<DAS_BIND_FUN(Skia_MergeFilters)>(module,lib,"Skia_MergeFilters",SideEffects::worstDefault,"Skia_MergeFilters",
        [](auto fn) { fn->arguments[0]->type->firstType->constant=false; });
    BIND(Skia_MatrixTransformFilter);
#undef BIND
}
}
