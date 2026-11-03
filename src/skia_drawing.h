#pragma once
#include "daScript/daScript.h"
#include "skia_api.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkRRect.h"
#include "include/core/SkSamplingOptions.h"
#include <vector>

using SkStrokeCap=SkPaint::Cap;
using SkStrokeJoin=SkPaint::Join;
using SkPaintStyle=SkPaint::Style;
// Plain row-major values cross the language boundary. SkMatrix's private cached
// classification never becomes zero-initialized container storage in daScript.
struct SkiaMatrix { float values[9]; };
inline SkMatrix Skia_ToMatrix(const SkiaMatrix& m) {
    auto a=m.values; return SkMatrix::MakeAll(a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8]);
}
inline SkiaMatrix Skia_FromMatrix(const SkMatrix& m) {
    SkiaMatrix result; m.get9(result.values); return result;
}

inline SkRect Skia_Rect(const das::float4& r) { return SkRect::MakeXYWH(r.x,r.y,r.z,r.w); }
inline das::float4 Skia_XYWH(const SkRect& r) { return {r.x(),r.y(),r.width(),r.height()}; }
inline void Skia_ResetPaint(SkPaint* p) { p->reset(); }
inline SkPaint* Skia_ClonePaint(const SkPaint* p) { return new SkPaint(*p); }
inline uint32_t Skia_GetColor(const SkPaint* p) { return p->getColor(); }
inline void Skia_SetAlpha(SkPaint* p,float alpha) { p->setAlphaf(alpha); }
inline float Skia_GetAlpha(const SkPaint* p) { return p->getAlphaf(); }
inline void Skia_SetBlendMode(SkPaint* p,SkBlendMode mode) { p->setBlendMode(mode); }
inline SkBlendMode Skia_GetBlendMode(const SkPaint* p) { return p->getBlendMode_or(SkBlendMode::kSrcOver); }
inline void Skia_SetStrokeCap(SkPaint* p,SkStrokeCap cap) { p->setStrokeCap(cap); }
inline SkStrokeCap Skia_GetStrokeCap(const SkPaint* p) { return p->getStrokeCap(); }
inline void Skia_SetStrokeJoin(SkPaint* p,SkStrokeJoin join) { p->setStrokeJoin(join); }
inline SkStrokeJoin Skia_GetStrokeJoin(const SkPaint* p) { return p->getStrokeJoin(); }
inline void Skia_SetStrokeMiter(SkPaint* p,float miter) { p->setStrokeMiter(miter); }
inline float Skia_GetStrokeMiter(const SkPaint* p) { return p->getStrokeMiter(); }
inline float Skia_GetStrokeWidth(const SkPaint* p) { return p->getStrokeWidth(); }
inline void Skia_SetPaintStyle(SkPaint* p,SkPaintStyle style) { p->setStyle(style); }
inline SkPaintStyle Skia_GetPaintStyle(const SkPaint* p) { return p->getStyle(); }
inline bool Skia_GetAntialias(const SkPaint* p) { return p->isAntiAlias(); }

inline void Skia_DrawLine(SkCanvas* c,const das::float2& a,const das::float2& b,const SkPaint* p) { c->drawLine(a.x,a.y,b.x,b.y,*p); }
inline void Skia_DrawOval(SkCanvas* c,const das::float4& r,const SkPaint* p) { c->drawOval(Skia_Rect(r),*p); }
inline void Skia_DrawRoundRect(SkCanvas* c,const das::float4& r,const das::float2& radius,const SkPaint* p) { c->drawRoundRect(Skia_Rect(r),radius.x,radius.y,*p); }
inline void Skia_DrawArc(SkCanvas* c,const das::float4& oval,float start,float sweep,bool center,const SkPaint* p) { c->drawArc(Skia_Rect(oval),start,sweep,center,*p); }
inline void Skia_DrawPaint(SkCanvas* c,const SkPaint* p) { c->drawPaint(*p); }
inline void Skia_ClipPath(SkCanvas* c,const SkPath* path,SkClipOp op,bool aa) { c->clipPath(*path,op,aa); }
inline void Skia_ClipRectOp(SkCanvas* c,const das::float4& r,SkClipOp op,bool aa) { c->clipRect(Skia_Rect(r),op,aa); }
inline void Skia_Skew(SkCanvas* c,float x,float y) { c->skew(x,y); }
inline void Skia_ConcatMatrix(SkCanvas* c,const SkiaMatrix& m) { c->concat(Skia_ToMatrix(m)); }
inline void Skia_SetMatrix(SkCanvas* c,const SkiaMatrix& m) { c->setMatrix(Skia_ToMatrix(m)); }
inline SkiaMatrix Skia_GetMatrix(SkCanvas* c) { return Skia_FromMatrix(c->getLocalToDeviceAs3x3()); }
inline void Skia_ResetMatrix(SkCanvas* c) { c->resetMatrix(); }
inline int Skia_SaveLayer(SkCanvas* c,const SkPaint* paint) { return c->saveLayer(nullptr,paint); }

inline SkPath* Skia_ClonePath(const SkPath* p) { return new SkPath(*p); }
inline void Skia_PathQuadTo(SkPath* p,const das::float2& control,const das::float2& end) { p->quadTo(control.x,control.y,end.x,end.y); }
inline void Skia_PathConicTo(SkPath* p,const das::float2& control,const das::float2& end,float weight) { p->conicTo(control.x,control.y,end.x,end.y,weight); }
inline void Skia_PathArcTo(SkPath* p,const das::float4& oval,float start,float sweep,bool move) { p->arcTo(Skia_Rect(oval),start,sweep,move); }
inline void Skia_PathAddRect(SkPath* p,const das::float4& r,SkPathDirection direction) { p->addRect(Skia_Rect(r),direction); }
inline void Skia_PathAddOval(SkPath* p,const das::float4& r,SkPathDirection direction) { p->addOval(Skia_Rect(r),direction); }
inline void Skia_PathAddRoundRect(SkPath* p,const das::float4& r,const das::float2& radius,SkPathDirection direction) { p->addRoundRect(Skia_Rect(r),radius.x,radius.y,direction); }
inline void Skia_PathSetFillType(SkPath* p,SkPathFillType fill) { p->setFillType(fill); }
inline SkPathFillType Skia_PathGetFillType(const SkPath* p) { return p->getFillType(); }
inline bool Skia_PathContains(const SkPath* p,const das::float2& point) { return p->contains(point.x,point.y); }
inline das::float4 Skia_PathBounds(const SkPath* p) { return Skia_XYWH(p->getBounds()); }
inline das::float4 Skia_PathTightBounds(const SkPath* p) { return Skia_XYWH(p->computeTightBounds()); }
inline void Skia_PathTransform(SkPath* p,const SkiaMatrix& m) { p->transform(Skia_ToMatrix(m)); }
inline void Skia_PathOffset(SkPath* p,const das::float2& offset) { p->offset(offset.x,offset.y); }
inline void Skia_PathAddPath(SkPath* p,const SkPath* other) { p->addPath(*other); }
inline bool Skia_PathIsEmpty(const SkPath* p) { return p->isEmpty(); }

inline SkiaMatrix Skia_MatrixIdentity() { return Skia_FromMatrix(SkMatrix::I()); }
inline SkiaMatrix Skia_MatrixMake(const das::float3& a,const das::float3& b,const das::float3& c) {
    return {{a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z}};
}
inline SkiaMatrix Skia_MatrixMultiply(const SkiaMatrix& a,const SkiaMatrix& b) { return Skia_FromMatrix(SkMatrix::Concat(Skia_ToMatrix(a),Skia_ToMatrix(b))); }
inline bool Skia_MatrixInvert(const SkiaMatrix& m,SkiaMatrix& inverse) {
    SkMatrix result; if(!Skia_ToMatrix(m).invert(&result)) return false;
    inverse=Skia_FromMatrix(result); return true;
}
inline das::float2 Skia_MatrixMapPoint(const SkiaMatrix& m,const das::float2& point) {
    auto out=Skia_ToMatrix(m).mapXY(point.x,point.y); return {out.x(),out.y()};
}
inline int Skia_ImageWidth(const SkImage* image) { return image->width(); }
inline int Skia_ImageHeight(const SkImage* image) { return image->height(); }
inline SkImage* Skia_ImageSubset(SkImage* image,int x,int y,int w,int h) {
    if(image->isTextureBacked() || x<0 || y<0 || w<=0 || h<=0 || w>image->width() || h>image->height() || x>image->width()-w || y>image->height()-h) return nullptr;
    return image->makeSubset(static_cast<GrDirectContext*>(nullptr),SkIRect::MakeXYWH(x,y,w,h)).release();
}
inline SkImage* Skia_ImageWithMipmaps(SkImage* image) {
    if(image->isTextureBacked()) return nullptr;
    return image->withDefaultMipmaps().release();
}
inline SkSamplingOptions Skia_Sampling(SkFilterMode filter,SkMipmapMode mipmap,bool cubic,float b,float c) {
    return cubic?SkSamplingOptions(SkCubicResampler{b,c}):SkSamplingOptions(filter,mipmap);
}
inline void Skia_DrawImageRect(SkCanvas* canvas,SkImage* image,const das::float4& src,const das::float4& dst,
        SkFilterMode filter,SkMipmapMode mipmap,bool cubic,float b,float c,const SkPaint* paint,bool strict) {
    canvas->drawImageRect(image,Skia_Rect(src),Skia_Rect(dst),Skia_Sampling(filter,mipmap,cubic,b,c),paint,
        strict?SkCanvas::kStrict_SrcRectConstraint:SkCanvas::kFast_SrcRectConstraint);
}
inline void Skia_DrawImageSampled(SkCanvas* canvas,SkImage* image,const das::float2& point,
        SkFilterMode filter,SkMipmapMode mipmap,bool cubic,float b,float c,const SkPaint* paint) {
    canvas->drawImage(image,point.x,point.y,Skia_Sampling(filter,mipmap,cubic,b,c),paint);
}
inline bool Skia_PixelRegion(SkSurface* surface,int x,int y,int w,int h,uint32_t capacity) {
    return x>=0 && y>=0 && w>0 && h>0 && w<=surface->width() && h<=surface->height() &&
        x<=surface->width()-w && y<=surface->height()-h && uint64_t(w)*uint64_t(h)<=capacity;
}
inline bool Skia_ReadPixelsArgb(SkSurface* surface,int x,int y,int w,int h,das::TArray<uint32_t>& pixels) {
    if(!Skia_PixelRegion(surface,x,y,w,h,pixels.size)) return false;
    if(!surface->readPixels(SkImageInfo::Make(w,h,kRGBA_8888_SkColorType,kUnpremul_SkAlphaType),pixels.data,size_t(w)*4,x,y)) return false;
    auto dst=reinterpret_cast<uint32_t*>(pixels.data);
    for(size_t i=0;i<size_t(w)*size_t(h);++i) {
        auto bytes=reinterpret_cast<uint8_t*>(dst+i);
        uint32_t argb=SkColorSetARGB(bytes[3],bytes[0],bytes[1],bytes[2]); dst[i]=argb;
    }
    return true;
}
inline bool Skia_WritePixelsArgb(SkSurface* surface,int x,int y,int w,int h,const das::TArray<uint32_t>& pixels) {
    if(!Skia_PixelRegion(surface,x,y,w,h,pixels.size)) return false;
    std::vector<uint8_t> bytes(size_t(w)*size_t(h)*4);
    auto src=reinterpret_cast<const uint32_t*>(pixels.data);
    for(size_t i=0;i<size_t(w)*size_t(h);++i) {
        bytes[i*4]=SkColorGetR(src[i]); bytes[i*4+1]=SkColorGetG(src[i]);
        bytes[i*4+2]=SkColorGetB(src[i]); bytes[i*4+3]=SkColorGetA(src[i]);
    }
    return surface->getCanvas()->writePixels(SkImageInfo::Make(w,h,kRGBA_8888_SkColorType,kUnpremul_SkAlphaType),bytes.data(),size_t(w)*4,x,y);
}
