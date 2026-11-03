#pragma once
namespace das {
inline void registerEffects(Module& module,ModuleLibrary& lib) {
#define TYPE(T) module.addAnnotation(new DummyTypeAnnotation(#T,#T,sizeof(T),alignof(T)))
    TYPE(SkShader); TYPE(SkPathEffect); TYPE(SkMaskFilter); TYPE(SkColorFilter); TYPE(SkImageFilter);
#undef TYPE
#define ENUM_BEGIN(T) { auto e=new Enumeration(#T); e->external=true; e->cppName=#T; e->baseType=Type::tInt; using Enum=T;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(Enum::native),LineInfo());
#define ENUM_END() module.addEnumeration(e); }
    ENUM_BEGIN(SkTileMode)
    VALUE(Clamp,kClamp) VALUE(Repeat,kRepeat) VALUE(Mirror,kMirror) VALUE(Decal,kDecal)
    ENUM_END()
    ENUM_BEGIN(SkBlurStyle)
    VALUE(Normal,kNormal_SkBlurStyle) VALUE(Solid,kSolid_SkBlurStyle)
    VALUE(Outer,kOuter_SkBlurStyle) VALUE(Inner,kInner_SkBlurStyle)
    ENUM_END()
#undef ENUM_BEGIN
#undef VALUE
#undef ENUM_END
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_EffectsError);
    BIND(Skia_SolidShader);
    BIND(Skia_LinearGradient);
    BIND(Skia_RadialGradient);
    BIND(Skia_SweepGradient);
    BIND(Skia_ConicalGradient);
    BIND(Skia_ImageShader);
    BIND(Skia_BlendShader);
    BIND(Skia_LocalShader);
    BIND(Skia_ShaderUnref);
    BIND(Skia_SetShader);
    BIND(Skia_DashEffect);
    BIND(Skia_CornerEffect);
    BIND(Skia_ComposePathEffect);
    BIND(Skia_SumPathEffect);
    BIND(Skia_PathEffectUnref);
    BIND(Skia_SetPathEffect);
    BIND(Skia_BlurMask);
    BIND(Skia_MaskFilterUnref);
    BIND(Skia_SetMaskFilter);
    BIND(Skia_BlendColorFilter);
    BIND(Skia_MatrixColorFilter);
    BIND(Skia_ComposeColorFilter);
    BIND(Skia_LightingColorFilter);
    BIND(Skia_LinearToSRGBFilter);
    BIND(Skia_SRGBToLinearFilter);
    BIND(Skia_ColorFilterUnref);
    BIND(Skia_SetColorFilter);
    BIND(Skia_BlurImageFilter);
    BIND(Skia_ShadowImageFilter);
    BIND(Skia_OffsetImageFilter);
    BIND(Skia_DilateImageFilter);
    BIND(Skia_ErodeImageFilter);
    BIND(Skia_ColorImageFilter);
    BIND(Skia_ComposeImageFilter);
    BIND(Skia_BlendImageFilter);
    BIND(Skia_CropImageFilter);
    BIND(Skia_ImageFilterUnref);
    BIND(Skia_SetImageFilter);
#undef BIND
}
}
