#pragma once
#include "skia_runtime.h"
#include "skia_effects.h"
#include "skia_picture.h"
#include <cmath>
#include <climits>
#include <string_view>
#include <vector>

inline SkImageFilter* Skia_GraphFilterResult(sk_sp<SkImageFilter> result) {
    if(!result) Skia_RuntimeFail("Image-filter factory rejected its inputs");
    return result.release();
}
inline bool Skia_GraphRuntimeValid(const SkRuntimeEffectBuilder* builder,float radius) {
    if(!builder->effect()->allowShader()) return Skia_RuntimeFail("Runtime image filters require a shader effect");
    if(!std::isfinite(radius) || radius<0) return Skia_RuntimeFail("Sample radius must be finite and nonnegative");
    return true;
}
inline SkImageFilter* Skia_RuntimeImageFilter(const SkRuntimeEffectBuilder* builder,const char* name,SkImageFilter* input,float radius) {
    if(!Skia_GraphRuntimeValid(builder,radius)) return nullptr;
    return Skia_GraphFilterResult(SkImageFilters::RuntimeShader(*builder,radius,name?name:"",sk_ref_sp(input)));
}
inline SkImageFilter* Skia_RuntimeImageFilterInputs(const SkRuntimeEffectBuilder* builder,const das::TArray<char*>& names,
        const das::TArray<const SkImageFilter*>& inputs,float radius) {
    if(!Skia_GraphRuntimeValid(builder,radius)) return nullptr;
    if(names.size!=inputs.size || names.size>uint64_t(INT_MAX) || names.size>builder->effect()->children().size()) {
        Skia_RuntimeFail("Input/name arrays must have equal size and fit the effect's child count"); return nullptr;
    }
    auto rawNames=reinterpret_cast<char* const*>(names.data);
    auto rawInputs=reinterpret_cast<const SkImageFilter* const*>(inputs.data);
    std::vector<std::string_view> childNames; std::vector<sk_sp<SkImageFilter>> children;
    childNames.reserve(names.size); children.reserve(inputs.size);
    for(uint64_t i=0;i<names.size;++i) {
        childNames.emplace_back(rawNames[i]?rawNames[i]:"");
        // Filters are immutable. Skia's factory takes non-const sk_sp solely for ownership.
        children.push_back(sk_ref_sp(const_cast<SkImageFilter*>(rawInputs[i])));
    }
    return Skia_GraphFilterResult(SkImageFilters::RuntimeShader(*builder,radius,childNames.data(),children.data(),int(children.size())));
}
inline bool Skia_GraphSamplingValid(bool cubic,float b,float c) {
    if(cubic && (!std::isfinite(b) || !std::isfinite(c) || b<0 || b>1 || c<0 || c>1))
        return Skia_RuntimeFail("Cubic B/C must be finite and in [0,1]");
    return true;
}
inline SkImageFilter* Skia_ImageSourceFilter(SkImage* image,const das::float4& source,const das::float4& destination,
        SkFilterMode filter,SkMipmapMode mipmap,bool cubic,float b,float c) {
    if(!Skia_PictureBounds(source) || !Skia_PictureBounds(destination)) {
        Skia_RuntimeFail("Image source/destination XYWH must have finite bounds and nonnegative sizes"); return nullptr;
    }
    if(!Skia_GraphSamplingValid(cubic,b,c)) return nullptr;
    return Skia_GraphFilterResult(SkImageFilters::Image(sk_ref_sp(image),Skia_Rect(source),Skia_Rect(destination),Skia_Sampling(filter,mipmap,cubic,b,c)));
}
inline SkImageFilter* Skia_PictureSourceFilter(SkPicture* picture,const das::float4& target) {
    if(!Skia_PictureBounds(target)) { Skia_RuntimeFail("Picture target XYWH must have finite bounds and nonnegative sizes"); return nullptr; }
    return Skia_GraphFilterResult(SkImageFilters::Picture(sk_ref_sp(picture),Skia_Rect(target)));
}
inline SkImageFilter* Skia_ShaderSourceFilter(SkShader* shader,bool dither) {
    return Skia_GraphFilterResult(SkImageFilters::Shader(sk_ref_sp(shader),dither?SkImageFilters::Dither::kYes:SkImageFilters::Dither::kNo));
}
inline SkImageFilter* Skia_MergeFilters(const das::TArray<const SkImageFilter*>& inputs) {
    if(inputs.size>uint64_t(INT_MAX)) { Skia_RuntimeFail("Too many merge inputs"); return nullptr; }
    auto raw=reinterpret_cast<const SkImageFilter* const*>(inputs.data);
    std::vector<sk_sp<SkImageFilter>> children; children.reserve(inputs.size);
    for(uint64_t i=0;i<inputs.size;++i) children.push_back(sk_ref_sp(const_cast<SkImageFilter*>(raw[i])));
    return Skia_GraphFilterResult(SkImageFilters::Merge(children.data(),int(children.size())));
}
inline SkImageFilter* Skia_MatrixTransformFilter(const SkiaMatrix& transform,SkFilterMode filter,SkMipmapMode mipmap,
        bool cubic,float b,float c,SkImageFilter* input) {
    auto matrix=Skia_ToMatrix(transform);
    if(!matrix.isFinite() || !matrix.invert(nullptr)) { Skia_RuntimeFail("Filter transform must be finite and invertible"); return nullptr; }
    if(!Skia_GraphSamplingValid(cubic,b,c)) return nullptr;
    return Skia_GraphFilterResult(SkImageFilters::MatrixTransform(matrix,Skia_Sampling(filter,mipmap,cubic,b,c),sk_ref_sp(input)));
}
