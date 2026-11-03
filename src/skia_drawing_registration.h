#pragma once
namespace das {
inline void registerDrawing(Module& module,ModuleLibrary& lib) {
#define ENUM_BEGIN(T) { auto e=new Enumeration(#T); e->external=true; e->cppName=#T; e->baseType=Type::tInt; using Enum=T;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(Enum::native),LineInfo());
#define ENUM_END() module.addEnumeration(e); }
    ENUM_BEGIN(SkBlendMode)
    VALUE(Clear,kClear) VALUE(Src,kSrc) VALUE(Dst,kDst) VALUE(SrcOver,kSrcOver)
    VALUE(DstOver,kDstOver) VALUE(SrcIn,kSrcIn) VALUE(DstIn,kDstIn)
    VALUE(SrcOut,kSrcOut) VALUE(DstOut,kDstOut) VALUE(SrcATop,kSrcATop)
    VALUE(DstATop,kDstATop) VALUE(Xor,kXor) VALUE(Plus,kPlus) VALUE(Modulate,kModulate)
    VALUE(Screen,kScreen) VALUE(Overlay,kOverlay) VALUE(Darken,kDarken) VALUE(Lighten,kLighten)
    VALUE(ColorDodge,kColorDodge) VALUE(ColorBurn,kColorBurn) VALUE(HardLight,kHardLight)
    VALUE(SoftLight,kSoftLight) VALUE(Difference,kDifference) VALUE(Exclusion,kExclusion)
    VALUE(Multiply,kMultiply) VALUE(Hue,kHue) VALUE(Saturation,kSaturation)
    VALUE(Color,kColor) VALUE(Luminosity,kLuminosity)
    ENUM_END()
    ENUM_BEGIN(SkStrokeCap)
    VALUE(Butt,kButt_Cap) VALUE(Round,kRound_Cap) VALUE(Square,kSquare_Cap)
    ENUM_END()
    ENUM_BEGIN(SkStrokeJoin)
    VALUE(Miter,kMiter_Join) VALUE(Round,kRound_Join) VALUE(Bevel,kBevel_Join)
    ENUM_END()
    ENUM_BEGIN(SkPaintStyle)
    VALUE(Fill,kFill_Style) VALUE(Stroke,kStroke_Style) VALUE(StrokeAndFill,kStrokeAndFill_Style)
    ENUM_END()
    ENUM_BEGIN(SkPathDirection)
    VALUE(CW,kCW) VALUE(CCW,kCCW)
    ENUM_END()
    ENUM_BEGIN(SkPathFillType)
    VALUE(Winding,kWinding) VALUE(EvenOdd,kEvenOdd) VALUE(InverseWinding,kInverseWinding) VALUE(InverseEvenOdd,kInverseEvenOdd)
    ENUM_END()
    ENUM_BEGIN(SkClipOp)
    VALUE(Difference,kDifference) VALUE(Intersect,kIntersect)
    ENUM_END()
    ENUM_BEGIN(SkFilterMode)
    VALUE(Nearest,kNearest) VALUE(Linear,kLinear)
    ENUM_END()
    ENUM_BEGIN(SkMipmapMode)
    VALUE(None,kNone) VALUE(Nearest,kNearest) VALUE(Linear,kLinear)
    ENUM_END()
#undef ENUM_BEGIN
#undef ENUM_END
#undef VALUE
    module.addAnnotation(new ManagedStructureAnnotation<SkiaMatrix>("SkiaMatrix",lib,"SkiaMatrix"));
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_ResetPaint); BIND(Skia_ClonePaint); BIND(Skia_GetColor);
    BIND(Skia_SetAlpha); BIND(Skia_GetAlpha); BIND(Skia_SetBlendMode); BIND(Skia_GetBlendMode);
    BIND(Skia_SetStrokeCap); BIND(Skia_GetStrokeCap); BIND(Skia_SetStrokeJoin); BIND(Skia_GetStrokeJoin);
    BIND(Skia_SetStrokeMiter); BIND(Skia_GetStrokeMiter); BIND(Skia_GetStrokeWidth);
    BIND(Skia_SetPaintStyle); BIND(Skia_GetPaintStyle); BIND(Skia_GetAntialias);
    BIND(Skia_DrawLine); BIND(Skia_DrawOval); BIND(Skia_DrawRoundRect); BIND(Skia_DrawArc); BIND(Skia_DrawPaint);
    BIND(Skia_ClipPath); BIND(Skia_ClipRectOp); BIND(Skia_Skew); BIND(Skia_ConcatMatrix);
    BIND(Skia_SetMatrix); BIND(Skia_ResetMatrix); BIND(Skia_SaveLayer);
    BIND(Skia_ClonePath); BIND(Skia_PathQuadTo); BIND(Skia_PathConicTo); BIND(Skia_PathArcTo);
    BIND(Skia_PathAddRect); BIND(Skia_PathAddOval); BIND(Skia_PathAddRoundRect);
    BIND(Skia_PathSetFillType); BIND(Skia_PathGetFillType); BIND(Skia_PathContains);
    BIND(Skia_PathBounds); BIND(Skia_PathTightBounds); BIND(Skia_PathTransform);
    BIND(Skia_PathOffset); BIND(Skia_PathAddPath); BIND(Skia_PathIsEmpty);
    BIND(Skia_MatrixInvert); BIND(Skia_MatrixMapPoint);
    BIND(Skia_ImageWidth); BIND(Skia_ImageHeight); BIND(Skia_ImageSubset); BIND(Skia_ImageWithMipmaps);
    BIND(Skia_DrawImageRect); BIND(Skia_DrawImageSampled);
    BIND(Skia_ReadPixelsArgb); BIND(Skia_WritePixelsArgb);
#undef BIND
#define VALUE_BIND(F) addExtern<DAS_BIND_FUN(F),SimNode_ExtFuncCallAndCopyOrMove>(module,lib,#F,SideEffects::worstDefault,#F)
    VALUE_BIND(Skia_MatrixIdentity); VALUE_BIND(Skia_MatrixMake); VALUE_BIND(Skia_MatrixMultiply); VALUE_BIND(Skia_GetMatrix);
#undef VALUE_BIND
}
}
