#pragma once
#include "skia_drawing.h"
#include "include/core/SkShader.h"
#include "include/core/SkColorFilter.h"
#include "include/core/SkImageFilter.h"
#include "include/core/SkMaskFilter.h"
#include "include/core/SkBlurTypes.h"
#include "include/core/SkPathEffect.h"
#include "include/effects/SkGradientShader.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/effects/SkCornerPathEffect.h"
#include "include/effects/SkImageFilters.h"
#include <cmath>
#include <climits>
#include <limits>
#include <string>

inline thread_local std::string skia_effect_error;
inline char* Skia_EffectsError(das::Context* context,das::LineInfoArg* at) {
    return context->allocateString(skia_effect_error.c_str(),uint32_t(skia_effect_error.size()),at);
}
template<typename T> inline bool Skia_EffectFail(const char* message,T*& out) {
    out=nullptr; skia_effect_error=message; return false;
}
template<typename T> inline bool Skia_EffectFinish(sk_sp<T> value,T*& out,bool nullable=false) {
    if(!value && !nullable) return Skia_EffectFail("Skia effect factory returned null",out);
    out=value.release(); return true;
}
inline bool Skia_Finite(const das::float2& p) { return std::isfinite(p.x) && std::isfinite(p.y); }
inline bool Skia_GradientStops(const das::TArray<uint32_t>& colors,const das::TArray<float>& positions) {
    if(colors.size<2 || colors.size>uint32_t(INT_MAX) || (positions.size && positions.size!=colors.size)) {
        skia_effect_error="Gradient needs >=2 colors and either zero positions or one per color"; return false;
    }
    auto p=reinterpret_cast<const float*>(positions.data);
    for(uint32_t i=0;i<positions.size;++i) {
        if(!std::isfinite(p[i]) || p[i]<0 || p[i]>1 || (i && p[i]<p[i-1])) {
            skia_effect_error="Gradient positions must be finite, nondecreasing and in [0,1]"; return false;
        }
    }
    return true;
}
inline bool Skia_SolidShader(uint32_t color,SkShader*& out) { return Skia_EffectFinish(SkShaders::Color(color),out); }
inline bool Skia_LinearGradient(const das::float2& start,const das::float2& end,
        const das::TArray<uint32_t>& colors,const das::TArray<float>& positions,SkTileMode tile,
        bool premul,const SkiaMatrix& local,SkShader*& out) {
    out=nullptr; if(!Skia_GradientStops(colors,positions)) return false;
    if(!Skia_Finite(start) || !Skia_Finite(end)) return Skia_EffectFail("Gradient points must be finite",out);
    SkPoint points[]={{start.x,start.y},{end.x,end.y}}; auto matrix=Skia_ToMatrix(local);
    return Skia_EffectFinish(SkGradientShader::MakeLinear(points,reinterpret_cast<const SkColor*>(colors.data),
        positions.size?reinterpret_cast<const float*>(positions.data):nullptr,int(colors.size),tile,
        premul?SkGradientShader::kInterpolateColorsInPremul_Flag:0,&matrix),out);
}
inline bool Skia_RadialGradient(const das::float2& center,float radius,
        const das::TArray<uint32_t>& colors,const das::TArray<float>& positions,SkTileMode tile,
        bool premul,const SkiaMatrix& local,SkShader*& out) {
    out=nullptr; if(!Skia_GradientStops(colors,positions)) return false;
    if(!Skia_Finite(center) || !std::isfinite(radius) || radius<0) return Skia_EffectFail("Invalid radial gradient center/radius",out);
    auto matrix=Skia_ToMatrix(local);
    return Skia_EffectFinish(SkGradientShader::MakeRadial({center.x,center.y},radius,
        reinterpret_cast<const SkColor*>(colors.data),positions.size?reinterpret_cast<const float*>(positions.data):nullptr,
        int(colors.size),tile,premul?SkGradientShader::kInterpolateColorsInPremul_Flag:0,&matrix),out);
}
inline bool Skia_SweepGradient(const das::float2& center,float start,float end,
        const das::TArray<uint32_t>& colors,const das::TArray<float>& positions,SkTileMode tile,
        bool premul,const SkiaMatrix& local,SkShader*& out) {
    out=nullptr; if(!Skia_GradientStops(colors,positions)) return false;
    if(!Skia_Finite(center) || !std::isfinite(start) || !std::isfinite(end) || start>end) return Skia_EffectFail("Invalid sweep center/angles",out);
    auto matrix=Skia_ToMatrix(local);
    return Skia_EffectFinish(SkGradientShader::MakeSweep(center.x,center.y,reinterpret_cast<const SkColor*>(colors.data),
        positions.size?reinterpret_cast<const float*>(positions.data):nullptr,int(colors.size),tile,start,end,
        premul?SkGradientShader::kInterpolateColorsInPremul_Flag:0,&matrix),out);
}
inline bool Skia_ConicalGradient(const das::float2& start,float startRadius,const das::float2& end,float endRadius,
        const das::TArray<uint32_t>& colors,const das::TArray<float>& positions,SkTileMode tile,
        bool premul,const SkiaMatrix& local,SkShader*& out) {
    out=nullptr; if(!Skia_GradientStops(colors,positions)) return false;
    if(!Skia_Finite(start) || !Skia_Finite(end) || !std::isfinite(startRadius) || !std::isfinite(endRadius) || startRadius<0 || endRadius<0)
        return Skia_EffectFail("Invalid conical gradient centers/radii",out);
    auto matrix=Skia_ToMatrix(local);
    return Skia_EffectFinish(SkGradientShader::MakeTwoPointConical({start.x,start.y},startRadius,{end.x,end.y},endRadius,
        reinterpret_cast<const SkColor*>(colors.data),positions.size?reinterpret_cast<const float*>(positions.data):nullptr,
        int(colors.size),tile,premul?SkGradientShader::kInterpolateColorsInPremul_Flag:0,&matrix),out);
}
inline bool Skia_ImageShader(SkImage* image,SkTileMode x,SkTileMode y,SkFilterMode filter,SkMipmapMode mipmap,
        bool cubic,float b,float c,const SkiaMatrix& local,SkShader*& out) {
    if(cubic && (!std::isfinite(b) || !std::isfinite(c) || b<0 || b>1 || c<0 || c>1)) return Skia_EffectFail("Cubic B/C must be in [0,1]",out);
    if(!image) return Skia_EffectFail("Image shader needs a non-null image",out);
    return Skia_EffectFinish(image->makeShader(x,y,Skia_Sampling(filter,mipmap,cubic,b,c),Skia_ToMatrix(local)),out);
}
inline bool Skia_BlendShader(SkBlendMode mode,SkShader* dst,SkShader* src,SkShader*& out) {
    if(!dst || !src) return Skia_EffectFail("Blend shaders must be non-null",out);
    return Skia_EffectFinish(SkShaders::Blend(mode,sk_ref_sp(dst),sk_ref_sp(src)),out);
}
inline bool Skia_LocalShader(SkShader* shader,const SkiaMatrix& local,SkShader*& out) {
    if(!shader) return Skia_EffectFail("Local-matrix shader must be non-null",out);
    return Skia_EffectFinish(shader->makeWithLocalMatrix(Skia_ToMatrix(local)),out);
}
inline void Skia_ShaderUnref(SkShader* p) { if(p) p->unref(); }
inline void Skia_SetShader(SkPaint* p,SkShader* shader) { p->setShader(sk_ref_sp(shader)); }

inline bool Skia_DashEffect(const das::TArray<float>& intervals,float phase,SkPathEffect*& out) {
    if(intervals.size<2 || intervals.size>uint32_t(INT_MAX) || intervals.size%2 || !std::isfinite(phase))
        return Skia_EffectFail("Dash needs an even number of >=2 intervals and finite phase",out);
    auto p=reinterpret_cast<const float*>(intervals.data); double sum=0;
    for(uint32_t i=0;i<intervals.size;++i) {
        if(!std::isfinite(p[i]) || p[i]<0) return Skia_EffectFail("Dash intervals must be finite and nonnegative",out);
        sum+=p[i];
    }
    if(sum<=0 || sum>std::numeric_limits<float>::max()) return Skia_EffectFail("Dash interval sum must be finite and positive",out);
    return Skia_EffectFinish(SkDashPathEffect::Make(p,int(intervals.size),phase),out);
}
inline bool Skia_CornerEffect(float radius,SkPathEffect*& out) {
    if(!std::isfinite(radius) || radius<=0) return Skia_EffectFail("Corner radius must be finite and positive",out);
    return Skia_EffectFinish(SkCornerPathEffect::Make(radius),out);
}
inline bool Skia_ComposePathEffect(SkPathEffect* outer,SkPathEffect* inner,SkPathEffect*& out) {
    if(!outer || !inner) return Skia_EffectFail("Composed path effects must be non-null",out);
    return Skia_EffectFinish(SkPathEffect::MakeCompose(sk_ref_sp(outer),sk_ref_sp(inner)),out);
}
inline bool Skia_SumPathEffect(SkPathEffect* a,SkPathEffect* b,SkPathEffect*& out) {
    if(!a || !b) return Skia_EffectFail("Summed path effects must be non-null",out);
    return Skia_EffectFinish(SkPathEffect::MakeSum(sk_ref_sp(a),sk_ref_sp(b)),out);
}
inline void Skia_PathEffectUnref(SkPathEffect* p) { if(p) p->unref(); }
inline void Skia_SetPathEffect(SkPaint* p,SkPathEffect* effect) { p->setPathEffect(sk_ref_sp(effect)); }
inline bool Skia_BlurMask(SkBlurStyle style,float sigma,bool respectCTM,SkMaskFilter*& out) {
    if(!std::isfinite(sigma) || sigma<=0) return Skia_EffectFail("Mask blur sigma must be finite and positive",out);
    return Skia_EffectFinish(SkMaskFilter::MakeBlur(style,sigma,respectCTM),out);
}
inline void Skia_MaskFilterUnref(SkMaskFilter* p) { if(p) p->unref(); }
inline void Skia_SetMaskFilter(SkPaint* p,SkMaskFilter* filter) { p->setMaskFilter(sk_ref_sp(filter)); }

// Color/image filters can validly return null (identity / source graphic).
// A bool status separates these outcomes from adapter validation failures.
inline bool Skia_BlendColorFilter(uint32_t color,SkBlendMode mode,SkColorFilter*& out) { return Skia_EffectFinish(SkColorFilters::Blend(color,mode),out,true); }
inline bool Skia_MatrixColorFilter(const das::TArray<float>& matrix,SkColorFilter*& out) {
    if(matrix.size!=20) return Skia_EffectFail("Color matrix needs exactly 20 row-major floats",out);
    auto p=reinterpret_cast<const float*>(matrix.data);
    for(int i=0;i<20;++i) if(!std::isfinite(p[i])) return Skia_EffectFail("Color matrix entries must be finite",out);
    return Skia_EffectFinish(SkColorFilters::Matrix(p),out,true);
}
inline bool Skia_ComposeColorFilter(SkColorFilter* outer,SkColorFilter* inner,SkColorFilter*& out) { return Skia_EffectFinish(SkColorFilters::Compose(sk_ref_sp(outer),sk_ref_sp(inner)),out,true); }
inline bool Skia_LightingColorFilter(uint32_t multiply,uint32_t add,SkColorFilter*& out) { return Skia_EffectFinish(SkColorFilters::Lighting(multiply,add),out,true); }
inline bool Skia_LinearToSRGBFilter(SkColorFilter*& out) { return Skia_EffectFinish(SkColorFilters::LinearToSRGBGamma(),out); }
inline bool Skia_SRGBToLinearFilter(SkColorFilter*& out) { return Skia_EffectFinish(SkColorFilters::SRGBToLinearGamma(),out); }
inline void Skia_ColorFilterUnref(SkColorFilter* p) { if(p) p->unref(); }
inline void Skia_SetColorFilter(SkPaint* p,SkColorFilter* filter) { p->setColorFilter(sk_ref_sp(filter)); }

inline bool Skia_Nonnegative(const das::float2& p) { return Skia_Finite(p) && p.x>=0 && p.y>=0; }
inline bool Skia_BlurImageFilter(const das::float2& sigma,SkTileMode tile,SkImageFilter* input,SkImageFilter*& out) {
    if(!Skia_Nonnegative(sigma)) return Skia_EffectFail("Blur sigma must be finite and nonnegative",out);
    return Skia_EffectFinish(SkImageFilters::Blur(sigma.x,sigma.y,tile,sk_ref_sp(input)),out,true);
}
inline bool Skia_ShadowImageFilter(const das::float2& offset,const das::float2& sigma,uint32_t color,SkImageFilter* input,SkImageFilter*& out) {
    if(!Skia_Finite(offset) || !Skia_Nonnegative(sigma)) return Skia_EffectFail("Invalid shadow offset/sigma",out);
    return Skia_EffectFinish(SkImageFilters::DropShadow(offset.x,offset.y,sigma.x,sigma.y,color,sk_ref_sp(input)),out,true);
}
inline bool Skia_OffsetImageFilter(const das::float2& offset,SkImageFilter* input,SkImageFilter*& out) {
    if(!Skia_Finite(offset)) return Skia_EffectFail("Offset must be finite",out);
    return Skia_EffectFinish(SkImageFilters::Offset(offset.x,offset.y,sk_ref_sp(input)),out,true);
}
inline bool Skia_DilateImageFilter(const das::float2& radius,SkImageFilter* input,SkImageFilter*& out) {
    if(!Skia_Nonnegative(radius)) return Skia_EffectFail("Dilate radius must be finite and nonnegative",out);
    return Skia_EffectFinish(SkImageFilters::Dilate(radius.x,radius.y,sk_ref_sp(input)),out,true);
}
inline bool Skia_ErodeImageFilter(const das::float2& radius,SkImageFilter* input,SkImageFilter*& out) {
    if(!Skia_Nonnegative(radius)) return Skia_EffectFail("Erode radius must be finite and nonnegative",out);
    return Skia_EffectFinish(SkImageFilters::Erode(radius.x,radius.y,sk_ref_sp(input)),out,true);
}
inline bool Skia_ColorImageFilter(SkColorFilter* color,SkImageFilter* input,SkImageFilter*& out) { return Skia_EffectFinish(SkImageFilters::ColorFilter(sk_ref_sp(color),sk_ref_sp(input)),out,true); }
inline bool Skia_ComposeImageFilter(SkImageFilter* outer,SkImageFilter* inner,SkImageFilter*& out) { return Skia_EffectFinish(SkImageFilters::Compose(sk_ref_sp(outer),sk_ref_sp(inner)),out,true); }
inline bool Skia_BlendImageFilter(SkBlendMode mode,SkImageFilter* background,SkImageFilter* foreground,SkImageFilter*& out) { return Skia_EffectFinish(SkImageFilters::Blend(mode,sk_ref_sp(background),sk_ref_sp(foreground)),out,true); }
inline bool Skia_CropImageFilter(const das::float4& rect,SkTileMode tile,SkImageFilter* input,SkImageFilter*& out) {
    if(!std::isfinite(rect.x) || !std::isfinite(rect.y) || !std::isfinite(rect.z) || !std::isfinite(rect.w) || rect.z<0 || rect.w<0 || !std::isfinite(rect.x+rect.z) || !std::isfinite(rect.y+rect.w))
        return Skia_EffectFail("Crop XYWH must be finite with nonnegative width/height",out);
    return Skia_EffectFinish(SkImageFilters::Crop(Skia_Rect(rect),tile,sk_ref_sp(input)),out,true);
}
inline void Skia_ImageFilterUnref(SkImageFilter* p) { if(p) p->unref(); }
inline void Skia_SetImageFilter(SkPaint* p,SkImageFilter* filter) { p->setImageFilter(sk_ref_sp(filter)); }
