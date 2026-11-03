#pragma once
namespace das {
inline void registerParagraph(Module& module,ModuleLibrary& lib) {
#define TYPE(T) module.addAnnotation(new DummyTypeAnnotation(#T,#T,sizeof(T),alignof(T)))
    TYPE(SkiaParagraphFonts); TYPE(SkiaParagraphTextStyle); TYPE(SkiaParagraphBuilder); TYPE(SkiaParagraph); TYPE(SkiaParagraphRects); TYPE(SkiaParagraphStrut);
#undef TYPE
#define ENUM_BEGIN(T) { auto e=new Enumeration(#T); e->external=true; e->cppName=#T; e->baseType=Type::tInt; using Enum=T;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(Enum::native),LineInfo());
#define ENUM_END() module.addEnumeration(e); }
    ENUM_BEGIN(SkiaPlaceholderAlignment)
    VALUE(Baseline,kBaseline) VALUE(AboveBaseline,kAboveBaseline) VALUE(BelowBaseline,kBelowBaseline)
    VALUE(Top,kTop) VALUE(Bottom,kBottom) VALUE(Middle,kMiddle)
    ENUM_END()
    ENUM_BEGIN(SkiaTextBaseline)
    VALUE(Alphabetic,kAlphabetic) VALUE(Ideographic,kIdeographic)
    ENUM_END()
    ENUM_BEGIN(SkiaTextHeightBehavior)
    VALUE(All,kAll) VALUE(DisableFirstAscent,kDisableFirstAscent) VALUE(DisableLastDescent,kDisableLastDescent) VALUE(DisableAll,kDisableAll)
    ENUM_END()
    ENUM_BEGIN(SkiaTextDecorationStyle)
    VALUE(Solid,kSolid) VALUE(Double,kDouble) VALUE(Dotted,kDotted) VALUE(Dashed,kDashed) VALUE(Wavy,kWavy)
    ENUM_END()
    ENUM_BEGIN(SkiaTextDecorationMode)
    VALUE(Gaps,kGaps) VALUE(Through,kThrough)
    ENUM_END()
    ENUM_BEGIN(SkiaParagraphAffinity)
    VALUE(Upstream,kUpstream) VALUE(Downstream,kDownstream)
    ENUM_END()
    ENUM_BEGIN(SkiaParagraphRectHeight)
    VALUE(Tight,kTight) VALUE(Max,kMax) VALUE(IncludeLineSpacingMiddle,kIncludeLineSpacingMiddle)
    VALUE(IncludeLineSpacingTop,kIncludeLineSpacingTop) VALUE(IncludeLineSpacingBottom,kIncludeLineSpacingBottom) VALUE(Strut,kStrut)
    ENUM_END()
    ENUM_BEGIN(SkiaParagraphRectWidth)
    VALUE(Tight,kTight) VALUE(Max,kMax)
    ENUM_END()
    ENUM_BEGIN(SkiaParagraphAlign)
    VALUE(Left,kLeft) VALUE(Right,kRight) VALUE(Center,kCenter) VALUE(Justify,kJustify) VALUE(Start,kStart) VALUE(End,kEnd)
    ENUM_END()
    ENUM_BEGIN(SkiaParagraphDirection)
    VALUE(RTL,kRtl) VALUE(LTR,kLtr)
    ENUM_END()
#undef ENUM_BEGIN
#undef VALUE
#undef ENUM_END
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_ParagraphError);
    BIND(Skia_NewParagraphFonts);
    BIND(Skia_DeleteParagraphFonts);
    BIND(Skia_ParagraphAddFont);
    BIND(Skia_NewParagraphTextStyle);
    BIND(Skia_DeleteParagraphTextStyle);
    BIND(Skia_ParagraphStyleFamilies);
    BIND(Skia_NewParagraphBuilder);
    BIND(Skia_DeleteParagraphBuilder);
    BIND(Skia_ParagraphPushStyle);
    BIND(Skia_ParagraphPopStyle);
    BIND(Skia_ParagraphAddText);
    BIND(Skia_BuildParagraph);
    BIND(Skia_DeleteParagraph);
    BIND(Skia_LayoutParagraph);
    BIND(Skia_ParagraphMetrics);
    BIND(Skia_ParagraphLineMetrics);
    BIND(Skia_DrawParagraph);
    BIND(Skia_ParagraphAddFontFace);
    BIND(Skia_NewParagraphBuilderLayout);
    BIND(Skia_FontTag);
    BIND(Skia_FontTagName);
    BIND(Skia_FontAxisCount);
    BIND(Skia_FontAxis);
    BIND(Skia_ParagraphFontArguments);
    BIND(Skia_ParagraphClearFontArguments);
    BIND(Skia_ParagraphDecoration);
    BIND(Skia_ParagraphAddShadow);
    BIND(Skia_ParagraphResetShadows);
    BIND(Skia_ParagraphBaselineShift);

    BIND(Skia_SetParagraphForeground);
    BIND(Skia_SetParagraphBackground);
    BIND(Skia_ParagraphAddFontFeature);
    BIND(Skia_ParagraphResetFontFeatures);

    BIND(Skia_NewParagraphStrut);
    BIND(Skia_DeleteParagraphStrut);
    BIND(Skia_NewParagraphBuilderWithStrut);
    BIND(Skia_ParagraphAddPlaceholder);
    BIND(Skia_ParagraphPlaceholderRects);

    BIND(Skia_ParagraphGraphemeBoundaryUtf16);
    BIND(Skia_ParagraphGraphemeInfoUtf16);
    BIND(Skia_ParagraphCaretUtf16);
    BIND(Skia_ParagraphTextLength);
    BIND(Skia_ParagraphUtf8ToUtf16);
    BIND(Skia_ParagraphUtf16ToUtf8);
    BIND(Skia_ParagraphHitTest);
    BIND(Skia_ParagraphWordBoundaryUtf16);
    BIND(Skia_ParagraphRangeRectsUtf16);
    BIND(Skia_DeleteParagraphRects);
    BIND(Skia_ParagraphRectCount);
    BIND(Skia_ParagraphRectAt);

#undef BIND
}
}
