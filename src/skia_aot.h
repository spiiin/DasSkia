#pragma once
#include "daScript/daScript.h"
#include "skia_api.h"
#include "skia_drawing.h"
#include "skia_codecs.h"
#include "skia_runtime.h"
#include "skia_filter_graph.h"
#include "skia_advanced_filters.h"
#include "skia_picture.h"
#include "skia_geometry.h"
#include "skia_effects.h"
#include "skia_text.h"
#include "skia_paragraph.h"
#ifdef DASSKIA_WITH_SDL
#include "skia_sdl.h"
#endif
MAKE_TYPE_FACTORY(SkSurface,SkSurface);
MAKE_TYPE_FACTORY(SkCanvas,SkCanvas);
MAKE_TYPE_FACTORY(SkPaint,SkPaint);
MAKE_TYPE_FACTORY(SkPath,SkPath);
MAKE_TYPE_FACTORY(SkImage,SkImage);
MAKE_TYPE_FACTORY(SkFont,SkFont);
MAKE_TYPE_FACTORY(SkiaText,SkiaText);
MAKE_TYPE_FACTORY(SkiaParagraphFonts,SkiaParagraphFonts);
MAKE_TYPE_FACTORY(SkiaParagraphTextStyle,SkiaParagraphTextStyle);
MAKE_TYPE_FACTORY(SkiaParagraphBuilder,SkiaParagraphBuilder);
MAKE_TYPE_FACTORY(SkiaParagraph,SkiaParagraph);
MAKE_TYPE_FACTORY(SkiaParagraphStrut,SkiaParagraphStrut);
MAKE_TYPE_FACTORY(SkiaParagraphRects,SkiaParagraphRects);

MAKE_TYPE_FACTORY(SkiaMatrix,SkiaMatrix);
MAKE_TYPE_FACTORY(SkRuntimeEffect,SkRuntimeEffect);
MAKE_TYPE_FACTORY(SkRuntimeEffectBuilder,SkRuntimeEffectBuilder);
MAKE_TYPE_FACTORY(SkBlender,SkBlender);
MAKE_TYPE_FACTORY(SkPictureRecorder,SkPictureRecorder);
MAKE_TYPE_FACTORY(SkPicture,SkPicture);
MAKE_TYPE_FACTORY(SkPathMeasure,SkPathMeasure);
MAKE_TYPE_FACTORY(SkOpBuilder,SkOpBuilder);
MAKE_TYPE_FACTORY(SkShader,SkShader);
MAKE_TYPE_FACTORY(SkPathEffect,SkPathEffect);
MAKE_TYPE_FACTORY(SkMaskFilter,SkMaskFilter);
MAKE_TYPE_FACTORY(SkColorFilter,SkColorFilter);
MAKE_TYPE_FACTORY(SkImageFilter,SkImageFilter);
#define SKIA_ENUM_FACTORY(T) DAS_BIND_ENUM_CAST(T); DAS_BASE_BIND_ENUM_GEN(T,T);
SKIA_ENUM_FACTORY(SkiaPlaceholderAlignment)
SKIA_ENUM_FACTORY(SkiaTextBaseline)
SKIA_ENUM_FACTORY(SkiaTextHeightBehavior)
SKIA_ENUM_FACTORY(SkiaTextDecorationStyle)
SKIA_ENUM_FACTORY(SkiaTextDecorationMode)
SKIA_ENUM_FACTORY(SkiaParagraphAffinity)
SKIA_ENUM_FACTORY(SkiaParagraphRectHeight)
SKIA_ENUM_FACTORY(SkiaParagraphRectWidth)
SKIA_ENUM_FACTORY(SkiaParagraphAlign)
SKIA_ENUM_FACTORY(SkiaParagraphDirection)
SKIA_ENUM_FACTORY(SkBlendMode)
SKIA_ENUM_FACTORY(SkStrokeCap)
SKIA_ENUM_FACTORY(SkStrokeJoin)
SKIA_ENUM_FACTORY(SkPaintStyle)
SKIA_ENUM_FACTORY(SkPathDirection)
SKIA_ENUM_FACTORY(SkPathFillType)
SKIA_ENUM_FACTORY(SkClipOp)
SKIA_ENUM_FACTORY(SkFilterMode)
SKIA_ENUM_FACTORY(SkMipmapMode)
SKIA_ENUM_FACTORY(SkPathOp)
SKIA_ENUM_FACTORY(SkTileMode)
SKIA_ENUM_FACTORY(SkBlurStyle)
SKIA_ENUM_FACTORY(SkColorChannel)
SKIA_ENUM_FACTORY(SkiaRuntimeKind)
SKIA_ENUM_FACTORY(SkRuntimeUniformType)
SKIA_ENUM_FACTORY(SkRuntimeChildType)
SKIA_ENUM_FACTORY(SkiaJpegDownsample)
SKIA_ENUM_FACTORY(SkiaJpegAlpha)
SKIA_ENUM_FACTORY(SkiaWebpCompression)
#undef SKIA_ENUM_FACTORY
#ifdef DASSKIA_WITH_SDL
MAKE_TYPE_FACTORY(SkiaWindow,SkiaWindow);
#endif
