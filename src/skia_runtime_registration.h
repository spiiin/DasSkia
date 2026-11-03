#pragma once
namespace das {
inline void registerRuntime(Module& module,ModuleLibrary& lib) {
#define TYPE(T) module.addAnnotation(new DummyTypeAnnotation(#T,#T,sizeof(T),alignof(T)))
    TYPE(SkRuntimeEffect); TYPE(SkRuntimeEffectBuilder); TYPE(SkBlender);
#undef TYPE
#define ENUM_BEGIN(T) { auto e=new Enumeration(#T); e->external=true; e->cppName=#T; e->baseType=Type::tInt; using Enum=T;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(Enum::native),LineInfo());
#define ENUM_END() module.addEnumeration(e); }
    ENUM_BEGIN(SkiaRuntimeKind) VALUE(Shader,Shader) VALUE(ColorFilter,ColorFilter) VALUE(Blender,Blender) ENUM_END()
    ENUM_BEGIN(SkRuntimeUniformType)
    VALUE(Float,kFloat) VALUE(Float2,kFloat2) VALUE(Float3,kFloat3) VALUE(Float4,kFloat4)
    VALUE(Float2x2,kFloat2x2) VALUE(Float3x3,kFloat3x3) VALUE(Float4x4,kFloat4x4)
    VALUE(Int,kInt) VALUE(Int2,kInt2) VALUE(Int3,kInt3) VALUE(Int4,kInt4)
    ENUM_END()
    ENUM_BEGIN(SkRuntimeChildType) VALUE(Shader,kShader) VALUE(ColorFilter,kColorFilter) VALUE(Blender,kBlender) ENUM_END()
#undef ENUM_BEGIN
#undef VALUE
#undef ENUM_END
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_RuntimeError);
    BIND(Skia_CompileRuntime);
    BIND(Skia_RuntimeUnref);
    BIND(Skia_RuntimeSource);
    BIND(Skia_RuntimeSupports);
    BIND(Skia_RuntimeUniformSize);
    BIND(Skia_RuntimeUniformCount);
    BIND(Skia_RuntimeChildCount);
    BIND(Skia_RuntimeUniformInfo);
    BIND(Skia_RuntimeUniformName);
    BIND(Skia_RuntimeChildInfo);
    BIND(Skia_RuntimeChildName);
    BIND(Skia_NewRuntimeBuilder);
    BIND(Skia_DeleteRuntimeBuilder);
    BIND(Skia_RuntimeSetFloats);
    BIND(Skia_RuntimeSetInts);
    BIND(Skia_RuntimeSetFloatVector);
    BIND(Skia_RuntimeSetIntVector);
    BIND(Skia_RuntimeSetMatrix);
    BIND(Skia_RuntimeSetShader);
    BIND(Skia_RuntimeSetColorFilter);
    BIND(Skia_RuntimeSetBlender);
    BIND(Skia_RuntimeMakeShader);
    BIND(Skia_RuntimeMakeColorFilter);
    BIND(Skia_RuntimeMakeBlender);
    BIND(Skia_ModeBlender);
    BIND(Skia_BlenderUnref);
    BIND(Skia_SetBlender);
    BIND(Skia_PaintBlendMode);
#undef BIND
}
}
