#pragma once
#include "skia_drawing.h"
#include "include/core/SkPathMeasure.h"
#include "include/core/SkPathUtils.h"
#include "include/core/SkString.h"
#include "include/pathops/SkPathOps.h"
#include "include/utils/SkParsePath.h"
#include <cmath>
#include <cstring>

// Factories create independent paths; input paths are never mutated.
inline SkPath* Skia_PathOp(const SkPath* a,const SkPath* b,SkPathOp op) {
    SkPath result;
    if(!a->isFinite() || !b->isFinite() || !Op(*a,*b,op,&result)) return nullptr;
    return new SkPath(std::move(result));
}
inline SkPath* Skia_PathSimplify(const SkPath* path) {
    SkPath result;
    if(!path->isFinite() || !Simplify(*path,&result)) return nullptr;
    return new SkPath(std::move(result));
}
inline SkPath* Skia_PathAsWinding(const SkPath* path) {
    SkPath result;
    if(!path->isFinite() || !AsWinding(*path,&result)) return nullptr;
    return new SkPath(std::move(result));
}
inline bool Skia_PathIsFinite(const SkPath* path) { return path->isFinite(); }
inline SkPath* Skia_PathFromSvg(const char* text,uint32_t length) {
    SkPath result;
    // Reject embedded NUL rather than silently parsing only a prefix.
    if((length && (!text || std::memchr(text,0,length))) || !SkParsePath::FromSVGString(text?text:"",&result) || !result.isFinite()) return nullptr;
    return new SkPath(std::move(result));
}
inline char* Skia_PathToSvg(const SkPath* path,bool relative,das::Context* context,das::LineInfoArg* at) {
    auto text=SkParsePath::ToSVGString(*path,relative?SkParsePath::PathEncoding::Relative:SkParsePath::PathEncoding::Absolute);
    return context->allocateString(text.c_str(),uint32_t(text.size()),at);
}
inline SkPath* Skia_PathFillWithPaint(const SkPath* path,const SkPaint* paint,float precision) {
    SkPath result;
    if(!path->isFinite() || !std::isfinite(precision) || precision<=0 ||
       !skpathutils::FillPathWithPaint(*path,*paint,&result,nullptr,precision) || !result.isFinite()) return nullptr;
    return new SkPath(std::move(result));
}

inline SkPathMeasure* Skia_NewPathMeasure(const SkPath* path,bool closed,float precision) {
    if(!path->isFinite() || !std::isfinite(precision) || precision<=0) return nullptr;
    return new SkPathMeasure(*path,closed,precision);
}
inline void Skia_DeletePathMeasure(SkPathMeasure* measure) { delete measure; }
inline bool Skia_PathMeasureSetPath(SkPathMeasure* measure,const SkPath* path,bool closed) {
    if(path && !path->isFinite()) return false;
    measure->setPath(path,closed); return true;
}
inline float Skia_PathMeasureLength(SkPathMeasure* measure) { return measure->getLength(); }
inline bool Skia_PathMeasureIsClosed(SkPathMeasure* measure) { return measure->isClosed(); }
inline bool Skia_PathMeasureNext(SkPathMeasure* measure) { return measure->nextContour(); }
inline bool Skia_PathMeasurePosTan(SkPathMeasure* measure,float distance,das::float2& position,das::float2& tangent) {
    SkPoint p; SkVector t;
    if(!std::isfinite(distance) || !measure->getPosTan(distance,&p,&t)) return false;
    position={p.x(),p.y()}; tangent={t.x(),t.y()}; return true;
}
inline bool Skia_PathMeasureMatrix(SkPathMeasure* measure,float distance,bool position,bool tangent,SkiaMatrix& out) {
    SkMatrix matrix;
    auto flags=SkPathMeasure::MatrixFlags((position?SkPathMeasure::kGetPosition_MatrixFlag:0) |
                                         (tangent?SkPathMeasure::kGetTangent_MatrixFlag:0));
    if(!std::isfinite(distance) || !measure->getMatrix(distance,&matrix,flags)) return false;
    out=Skia_FromMatrix(matrix); return true;
}
inline SkPath* Skia_PathMeasureSegment(SkPathMeasure* measure,float start,float stop) {
    SkPath result;
    if(!std::isfinite(start) || !std::isfinite(stop)) return nullptr;
    float length=measure->getLength();
    start=std::max(0.0f,std::min(start,length));
    stop=std::max(0.0f,std::min(stop,length));
    // m138 can return true for equal distances despite the public header contract.
    // This factory promises a nonempty interval and always starts a new contour.
    if(!(start<stop) || !measure->getSegment(start,stop,&result,true)) return nullptr;
    return new SkPath(std::move(result));
}
inline SkOpBuilder* Skia_NewPathBuilder() { return new SkOpBuilder(); }
inline void Skia_DeletePathBuilder(SkOpBuilder* builder) { delete builder; }
inline void Skia_PathBuilderAdd(SkOpBuilder* builder,const SkPath* path,SkPathOp op) { builder->add(*path,op); }
inline SkPath* Skia_PathBuilderResolve(SkOpBuilder* builder) {
    SkPath result;
    if(!builder->resolve(&result)) return nullptr;
    return new SkPath(std::move(result));
}
