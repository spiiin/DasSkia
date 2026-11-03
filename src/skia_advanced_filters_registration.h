#pragma once
namespace das {
inline void registerAdvancedFilters(Module& module,ModuleLibrary& lib) {
    auto e=new Enumeration("SkColorChannel"); e->external=true; e->cppName="SkColorChannel"; e->baseType=Type::tInt;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(SkColorChannel::native),LineInfo());
    VALUE(R,kR) VALUE(G,kG) VALUE(B,kB) VALUE(A,kA)
#undef VALUE
    module.addEnumeration(e);
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_EmptyFilter);
    BIND(Skia_ConvolutionFilter);
    BIND(Skia_DisplacementFilter);
    BIND(Skia_ArithmeticFilter);
    BIND(Skia_CustomBlendFilter);
    BIND(Skia_TileFilter);
    BIND(Skia_MagnifierFilter);
    BIND(Skia_ShadowOnlyFilter);
    BIND(Skia_DistantDiffuseFilter);
    BIND(Skia_DistantSpecularFilter);
    BIND(Skia_PointDiffuseFilter);
    BIND(Skia_PointSpecularFilter);
    BIND(Skia_SpotDiffuseFilter);
    BIND(Skia_SpotSpecularFilter);
#undef BIND
}
}
