#pragma once
#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkData.h"
#include "include/core/SkImage.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkStream.h"
#include "include/core/SkSurface.h"
#include "include/encode/SkPngEncoder.h"
#include <cstdint>

// These are C++ adapters, not a separately stable C ABI. Raw pointers retain
// Skia ownership contracts; boost scopes only lend them to synchronous blocks.
inline SkSurface* Skia_NewRaster(int width, int height) {
    if (width <= 0 || height <= 0 || width > 16384 || height > 16384) return nullptr;
    return SkSurfaces::Raster(SkImageInfo::Make(width,height,kRGBA_8888_SkColorType,
        kPremul_SkAlphaType)).release();
}
inline void Skia_SurfaceUnref(SkSurface* p) { if (p) p->unref(); }
inline SkCanvas* Skia_GetCanvas(SkSurface* p) { return p->getCanvas(); }
inline int Skia_SurfaceWidth(SkSurface* p) { return p->width(); }
inline int Skia_SurfaceHeight(SkSurface* p) { return p->height(); }
inline SkPaint* Skia_NewPaint() { return new SkPaint(); }
inline void Skia_DeletePaint(SkPaint* p) { delete p; }
inline void Skia_SetColor(SkPaint* p, uint32_t color) { p->setColor(color); }
inline void Skia_SetAntialias(SkPaint* p, bool aa) { p->setAntiAlias(aa); }
inline void Skia_SetStroke(SkPaint* p, bool stroke, float width) {
    p->setStyle(stroke ? SkPaint::kStroke_Style : SkPaint::kFill_Style);
    p->setStrokeWidth(width);
}
inline SkPath* Skia_NewPath() { return new SkPath(); }
inline void Skia_DeletePath(SkPath* p) { delete p; }
inline void Skia_PathMoveTo(SkPath* p,float x,float y) { p->moveTo(x,y); }
inline void Skia_PathLineTo(SkPath* p,float x,float y) { p->lineTo(x,y); }
inline void Skia_PathCubicTo(SkPath* p,float x1,float y1,float x2,float y2,float x3,float y3) { p->cubicTo(x1,y1,x2,y2,x3,y3); }
inline void Skia_PathClose(SkPath* p) { p->close(); }
inline void Skia_PathReset(SkPath* p) { p->reset(); }
inline void Skia_Clear(SkCanvas* c,uint32_t color) { c->clear(color); }
inline void Skia_DrawRect(SkCanvas* c,float x,float y,float w,float h,const SkPaint* p) { c->drawRect(SkRect::MakeXYWH(x,y,w,h),*p); }
inline void Skia_DrawCircle(SkCanvas* c,float x,float y,float radius,const SkPaint* p) { c->drawCircle(x,y,radius,*p); }
inline void Skia_DrawPath(SkCanvas* c,const SkPath* path,const SkPaint* p) { c->drawPath(*path,*p); }
inline void Skia_DrawImage(SkCanvas* c,SkImage* image,float x,float y) { c->drawImage(image,x,y); }
inline int Skia_Save(SkCanvas* c) { return c->save(); }
inline int Skia_SaveCount(SkCanvas* c) { return c->getSaveCount(); }
inline void Skia_RestoreToCount(SkCanvas* c,int count) { c->restoreToCount(count); }
inline void Skia_Translate(SkCanvas* c,float x,float y) { c->translate(x,y); }
inline void Skia_Scale(SkCanvas* c,float x,float y) { c->scale(x,y); }
inline void Skia_Rotate(SkCanvas* c,float degrees) { c->rotate(degrees); }
inline void Skia_ClipRect(SkCanvas* c,float x,float y,float w,float h) { c->clipRect(SkRect::MakeXYWH(x,y,w,h)); }
inline SkImage* Skia_Snapshot(SkSurface* s) { return s->makeImageSnapshot().release(); }
inline SkImage* Skia_LoadImage(const char* path) {
    auto data=SkData::MakeFromFileName(path);
    return data ? SkImages::DeferredFromEncodedData(std::move(data)).release() : nullptr;
}
inline void Skia_ImageUnref(SkImage* p) { if(p) p->unref(); }
inline bool Skia_SavePng(SkSurface* s,const char* path) {
    // This operation is intentionally raster-only. GPU readback needs a context.
    SkPixmap pixels;
    if (!s->peekPixels(&pixels)) return false;
    SkFILEWStream out(path);
    if (!out.isValid()) return false;
    bool ok=SkPngEncoder::Encode(&out,pixels,{});
    out.flush();
    return ok && out.bytesWritten()>0;
}
inline bool Skia_ReadPixel(SkSurface* s,int x,int y,uint32_t& argb) {
    if (x<0 || y<0 || x>=s->width() || y>=s->height()) return false;
    uint8_t pixel[4]{};
    auto info=SkImageInfo::Make(1,1,kRGBA_8888_SkColorType,kUnpremul_SkAlphaType);
    if(!s->readPixels(info,pixel,4,x,y)) return false;
    argb=SkColorSetARGB(pixel[3],pixel[0],pixel[1],pixel[2]); return true;
}
