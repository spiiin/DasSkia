#pragma once
namespace das {
inline void registerCodecs(Module& module,ModuleLibrary& lib) {
#define ENUM_BEGIN(T) {auto e=new Enumeration(#T);e->external=true;e->cppName=#T;e->baseType=Type::tInt;using Enum=T;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(Enum::native),LineInfo());
#define ENUM_END() module.addEnumeration(e);}
    ENUM_BEGIN(SkiaJpegDownsample) VALUE(YUV420,k420) VALUE(YUV422,k422) VALUE(YUV444,k444) ENUM_END()
    ENUM_BEGIN(SkiaJpegAlpha) VALUE(Ignore,kIgnore) VALUE(BlendOnBlack,kBlendOnBlack) ENUM_END()
    ENUM_BEGIN(SkiaWebpCompression) VALUE(Lossy,kLossy) VALUE(Lossless,kLossless) ENUM_END()
#undef ENUM_BEGIN
#undef VALUE
#undef ENUM_END
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_SaveJpeg);BIND(Skia_SaveWebp);BIND(Skia_EncodeJpeg);BIND(Skia_EncodeWebp);
    BIND(Skia_EncodePng);BIND(Skia_ImageFromBytes);BIND(Skia_CodecError);
#undef BIND
}
}
