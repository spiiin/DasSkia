#pragma once
#include "skia_filter_graph.h"
#include "include/core/SkPoint3.h"
#include <cmath>
#include <climits>

inline bool Skia_AdvancedFail(const char* message,SkImageFilter*& out) { out=nullptr; return Skia_RuntimeFail(message); }
inline bool Skia_AdvancedFinish(sk_sp<SkImageFilter> value,SkImageFilter*& out,bool nullable=false) {
    if(!value && !nullable) return Skia_AdvancedFail("Skia image-filter factory rejected the parameters",out);
    out=value.release(); return true;
}
inline bool Skia_AdvancedCrop(bool enabled,const das::float4& rect) {
    if(enabled && !Skia_PictureBounds(rect)) return Skia_RuntimeFail("Crop XYWH needs finite bounds and nonnegative sizes");
    return true;
}
inline SkImageFilters::CropRect Skia_NativeCrop(bool enabled,const das::float4& rect) {
    return enabled?SkImageFilters::CropRect(Skia_Rect(rect)):SkImageFilters::CropRect();
}
inline bool Skia_Finite3(const das::float3& p) { return std::isfinite(p.x) && std::isfinite(p.y) && std::isfinite(p.z); }
inline bool Skia_EmptyFilter(SkImageFilter*& out) { return Skia_AdvancedFinish(SkImageFilters::Empty(),out); }
inline bool Skia_ConvolutionFilter(const das::int2& size,const das::TArray<float>& kernel,float gain,float bias,
        const das::int2& offset,SkTileMode tile,bool alpha,bool cropped,const das::float4& crop,SkImageFilter* input,SkImageFilter*& out) {
    out=nullptr;
    if(size.x<=0 || size.y<=0 || uint64_t(size.x)*uint64_t(size.y)!=kernel.size ||
       offset.x<0 || offset.y<0 || offset.x>=size.x || offset.y>=size.y || !std::isfinite(gain) || !std::isfinite(bias))
        return Skia_AdvancedFail("Kernel size/count/offset or gain/bias is invalid",out);
    auto weights=reinterpret_cast<const float*>(kernel.data);
    for(uint64_t i=0;i<kernel.size;++i) if(!std::isfinite(weights[i])) return Skia_AdvancedFail("Kernel weights must be finite",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::MatrixConvolution({size.x,size.y},weights,gain,bias,{offset.x,offset.y},
        tile,alpha,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_DisplacementFilter(SkColorChannel x,SkColorChannel y,float scale,SkImageFilter* displacement,
        SkImageFilter* color,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!std::isfinite(scale)) return Skia_AdvancedFail("Displacement scale must be finite",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::DisplacementMap(x,y,scale,sk_ref_sp(displacement),sk_ref_sp(color),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_ArithmeticFilter(const das::float4& k,bool premul,SkImageFilter* background,SkImageFilter* foreground,
        bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!std::isfinite(k.x) || !std::isfinite(k.y) || !std::isfinite(k.z) || !std::isfinite(k.w)) return Skia_AdvancedFail("Arithmetic coefficients must be finite",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::Arithmetic(k.x,k.y,k.z,k.w,premul,sk_ref_sp(background),sk_ref_sp(foreground),Skia_NativeCrop(cropped,crop)),out,true);
}
inline bool Skia_CustomBlendFilter(SkBlender* blender,SkImageFilter* background,SkImageFilter* foreground,
        bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr; if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::Blend(sk_ref_sp(blender),sk_ref_sp(background),sk_ref_sp(foreground),Skia_NativeCrop(cropped,crop)),out,true);
}
inline bool Skia_TileFilter(const das::float4& source,const das::float4& destination,SkImageFilter* input,SkImageFilter*& out) {
    if(!Skia_PictureBounds(source) || !Skia_PictureBounds(destination)) return Skia_AdvancedFail("Tile source/destination need finite XYWH and nonnegative sizes",out);
    return Skia_AdvancedFinish(SkImageFilters::Tile(Skia_Rect(source),Skia_Rect(destination),sk_ref_sp(input)),out);
}
inline bool Skia_MagnifierFilter(const das::float4& lens,float zoom,float inset,SkFilterMode filter,SkMipmapMode mipmap,
        bool cubic,float b,float c,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_PictureBounds(lens) || lens.z<=0 || lens.w<=0 || !std::isfinite(zoom) || zoom<=0 || !std::isfinite(inset) || inset<0)
        return Skia_AdvancedFail("Lens must be finite/nonempty, zoom finite/positive, inset finite/nonnegative",out);
    if(!Skia_GraphSamplingValid(cubic,b,c) || !Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::Magnifier(Skia_Rect(lens),zoom,inset,Skia_Sampling(filter,mipmap,cubic,b,c),sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out,true);
}
inline bool Skia_ShadowOnlyFilter(const das::float2& offset,const das::float2& sigma,uint32_t color,SkImageFilter* input,
        bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite(offset) || !Skia_Nonnegative(sigma)) return Skia_AdvancedFail("Invalid shadow offset/sigma",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::DropShadowOnly(offset.x,offset.y,sigma.x,sigma.y,color,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_DistantDiffuseFilter(const das::float3& direction,uint32_t color,float depth,float coefficient,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite3(direction) || !std::isfinite(depth) || !std::isfinite(coefficient) || coefficient<0) return Skia_AdvancedFail("Lighting parameters must be finite and reflectance nonnegative",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::DistantLitDiffuse({direction.x,direction.y,direction.z},color,depth,coefficient,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_DistantSpecularFilter(const das::float3& direction,uint32_t color,float depth,float coefficient,float shininess,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite3(direction) || !std::isfinite(depth) || !std::isfinite(coefficient) || coefficient<0 || !std::isfinite(shininess)) return Skia_AdvancedFail("Lighting parameters must be finite and reflectance nonnegative",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::DistantLitSpecular({direction.x,direction.y,direction.z},color,depth,coefficient,shininess,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_PointDiffuseFilter(const das::float3& location,uint32_t color,float depth,float coefficient,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite3(location) || !std::isfinite(depth) || !std::isfinite(coefficient) || coefficient<0) return Skia_AdvancedFail("Lighting parameters must be finite and reflectance nonnegative",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::PointLitDiffuse({location.x,location.y,location.z},color,depth,coefficient,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_PointSpecularFilter(const das::float3& location,uint32_t color,float depth,float coefficient,float shininess,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite3(location) || !std::isfinite(depth) || !std::isfinite(coefficient) || coefficient<0 || !std::isfinite(shininess)) return Skia_AdvancedFail("Lighting parameters must be finite and reflectance nonnegative",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::PointLitSpecular({location.x,location.y,location.z},color,depth,coefficient,shininess,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_SpotDiffuseFilter(const das::float3& location,const das::float3& target,float falloff,float cutoff,uint32_t color,float depth,float coefficient,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite3(location) || !std::isfinite(depth) || !std::isfinite(coefficient) || coefficient<0 || !Skia_Finite3(target) || !std::isfinite(falloff) || !std::isfinite(cutoff)) return Skia_AdvancedFail("Lighting parameters must be finite and reflectance nonnegative",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::SpotLitDiffuse({location.x,location.y,location.z},{target.x,target.y,target.z},falloff,cutoff,color,depth,coefficient,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
inline bool Skia_SpotSpecularFilter(const das::float3& location,const das::float3& target,float falloff,float cutoff,uint32_t color,float depth,float coefficient,float shininess,SkImageFilter* input,bool cropped,const das::float4& crop,SkImageFilter*& out) {
    out=nullptr;
    if(!Skia_Finite3(location) || !std::isfinite(depth) || !std::isfinite(coefficient) || coefficient<0 || !std::isfinite(shininess) || !Skia_Finite3(target) || !std::isfinite(falloff) || !std::isfinite(cutoff)) return Skia_AdvancedFail("Lighting parameters must be finite and reflectance nonnegative",out);
    if(!Skia_AdvancedCrop(cropped,crop)) return false;
    return Skia_AdvancedFinish(SkImageFilters::SpotLitSpecular({location.x,location.y,location.z},{target.x,target.y,target.z},falloff,cutoff,color,depth,coefficient,shininess,sk_ref_sp(input),Skia_NativeCrop(cropped,crop)),out);
}
