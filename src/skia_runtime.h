#pragma once
#include "skia_drawing.h"
#include "include/effects/SkRuntimeEffect.h"
#include <climits>
#include <cstring>
#include <string>
using SkRuntimeUniformType=SkRuntimeEffect::Uniform::Type;
using SkRuntimeChildType=SkRuntimeEffect::ChildType;
enum class SkiaRuntimeKind { Shader, ColorFilter, Blender };
inline thread_local std::string skia_runtime_error;
inline bool Skia_RuntimeFail(const char* message) { skia_runtime_error=message; return false; }
inline char* Skia_RuntimeError(das::Context* context,das::LineInfoArg* at) {
    return context->allocateString(skia_runtime_error.c_str(),uint32_t(skia_runtime_error.size()),at);
}
inline SkRuntimeEffect* Skia_CompileRuntime(const char* source,uint32_t length,SkiaRuntimeKind kind,bool unoptimized) {
    SkRuntimeEffect::Options options; options.forceUnoptimized=unoptimized;
    SkString text(source?source:"",source?length:0); SkRuntimeEffect::Result result;
    switch(kind) {
        case SkiaRuntimeKind::Shader: result=SkRuntimeEffect::MakeForShader(std::move(text),options); break;
        case SkiaRuntimeKind::ColorFilter: result=SkRuntimeEffect::MakeForColorFilter(std::move(text),options); break;
        case SkiaRuntimeKind::Blender: result=SkRuntimeEffect::MakeForBlender(std::move(text),options); break;
        default: Skia_RuntimeFail("Invalid runtime effect kind"); return nullptr;
    }
    if(!result.effect) skia_runtime_error.assign(result.errorText.c_str(),result.errorText.size());
    return result.effect.release();
}
inline void Skia_RuntimeUnref(SkRuntimeEffect* effect) { if(effect) effect->unref(); }
inline char* Skia_RuntimeSource(const SkRuntimeEffect* effect,das::Context* context,das::LineInfoArg* at) {
    auto& s=effect->source(); return context->allocateString(s.c_str(),uint32_t(s.size()),at);
}
inline bool Skia_RuntimeSupports(const SkRuntimeEffect* effect,SkiaRuntimeKind kind) {
    switch(kind) {
        case SkiaRuntimeKind::Shader:return effect->allowShader();
        case SkiaRuntimeKind::ColorFilter:return effect->allowColorFilter();
        case SkiaRuntimeKind::Blender:return effect->allowBlender();
        default:return false;
    }
}
inline uint64_t Skia_RuntimeUniformSize(const SkRuntimeEffect* effect) { return uint64_t(effect->uniformSize()); }
inline int Skia_RuntimeUniformCount(const SkRuntimeEffect* effect) { return int(effect->uniforms().size()); }
inline int Skia_RuntimeChildCount(const SkRuntimeEffect* effect) { return int(effect->children().size()); }
inline bool Skia_RuntimeUniformInfo(const SkRuntimeEffect* effect,int index,SkRuntimeUniformType& type,int& count,uint32_t& flags,uint64_t& offset,uint64_t& bytes) {
    if(index<0 || size_t(index)>=effect->uniforms().size()) return false;
    auto& u=effect->uniforms()[index]; type=u.type; count=u.count; flags=u.flags; offset=u.offset; bytes=u.sizeInBytes(); return true;
}
inline char* Skia_RuntimeUniformName(const SkRuntimeEffect* effect,int index,das::Context* context,das::LineInfoArg* at) {
    auto name=(index>=0 && size_t(index)<effect->uniforms().size())?effect->uniforms()[index].name:std::string_view();
    return context->allocateString(name.data(),uint32_t(name.size()),at);
}
inline bool Skia_RuntimeChildInfo(const SkRuntimeEffect* effect,int index,SkRuntimeChildType& type,int& slot) {
    if(index<0 || size_t(index)>=effect->children().size()) return false;
    auto& c=effect->children()[index]; type=c.type; slot=c.index; return true;
}
inline char* Skia_RuntimeChildName(const SkRuntimeEffect* effect,int index,das::Context* context,das::LineInfoArg* at) {
    auto name=(index>=0 && size_t(index)<effect->children().size())?effect->children()[index].name:std::string_view();
    return context->allocateString(name.data(),uint32_t(name.size()),at);
}
inline SkRuntimeEffectBuilder* Skia_NewRuntimeBuilder(SkRuntimeEffect* effect) { return new SkRuntimeEffectBuilder(sk_ref_sp(effect)); }
inline void Skia_DeleteRuntimeBuilder(SkRuntimeEffectBuilder* builder) { delete builder; }
inline bool Skia_UniformIsInt(SkRuntimeUniformType type) {
    using T=SkRuntimeUniformType; return type==T::kInt || type==T::kInt2 || type==T::kInt3 || type==T::kInt4;
}
template<typename T> inline bool Skia_SetRuntimeValues(SkRuntimeEffectBuilder* builder,const char* name,const T* data,uint64_t count,bool integer) {
    auto uniform=builder->uniform(name?name:""); auto u=uniform.fVar;
    if(!u || count>uint64_t(INT_MAX) || Skia_UniformIsInt(u->type)!=integer || uint64_t(count)*sizeof(T)!=u->sizeInBytes())
        return Skia_RuntimeFail("Missing uniform, incorrect numeric type or element count");
    return uniform.set(data,int(count));
}
inline bool Skia_RuntimeSetFloats(SkRuntimeEffectBuilder* builder,const char* name,const das::TArray<float>& values) {
    return Skia_SetRuntimeValues(builder,name,reinterpret_cast<const float*>(values.data),values.size,false);
}
inline bool Skia_RuntimeSetInts(SkRuntimeEffectBuilder* builder,const char* name,const das::TArray<int32_t>& values) {
    return Skia_SetRuntimeValues(builder,name,reinterpret_cast<const int32_t*>(values.data),values.size,true);
}
inline bool Skia_RuntimeSetFloatVector(SkRuntimeEffectBuilder* builder,const char* name,const das::float4& value,int count) {
    using T=SkRuntimeUniformType; static constexpr T types[]={T::kFloat,T::kFloat2,T::kFloat3,T::kFloat4};
    auto u=builder->effect()->findUniform(name?name:"");
    if(count<1 || count>4 || !u || u->isArray() || u->type!=types[count-1]) return Skia_RuntimeFail("Missing scalar/vector float uniform or wrong type");
    float data[]={value.x,value.y,value.z,value.w}; return Skia_SetRuntimeValues(builder,name,data,uint32_t(count),false);
}
inline bool Skia_RuntimeSetIntVector(SkRuntimeEffectBuilder* builder,const char* name,const das::int4& value,int count) {
    using T=SkRuntimeUniformType; static constexpr T types[]={T::kInt,T::kInt2,T::kInt3,T::kInt4};
    auto u=builder->effect()->findUniform(name?name:"");
    if(count<1 || count>4 || !u || u->isArray() || u->type!=types[count-1]) return Skia_RuntimeFail("Missing scalar/vector integer uniform or wrong type");
    int32_t data[]={value.x,value.y,value.z,value.w}; return Skia_SetRuntimeValues(builder,name,data,uint32_t(count),true);
}
inline bool Skia_RuntimeSetMatrix(SkRuntimeEffectBuilder* builder,const char* name,const SkiaMatrix& value) {
    auto uniform=builder->uniform(name?name:""); auto u=uniform.fVar;
    if(!u || u->isArray() || u->type!=SkRuntimeUniformType::kFloat3x3) return Skia_RuntimeFail("Expected one float3x3 uniform");
    uniform=Skia_ToMatrix(value); return true;
}
inline bool Skia_RuntimeSetShader(SkRuntimeEffectBuilder* builder,const char* name,SkShader* child) {
    auto slot=builder->child(name?name:"");
    if(!slot.fChild || slot.fChild->type!=SkRuntimeChildType::kShader) return Skia_RuntimeFail("Missing child or incorrect child type");
    if(child) slot=sk_ref_sp(child); else slot=nullptr;
    return true;
}
inline bool Skia_RuntimeSetColorFilter(SkRuntimeEffectBuilder* builder,const char* name,SkColorFilter* child) {
    auto slot=builder->child(name?name:"");
    if(!slot.fChild || slot.fChild->type!=SkRuntimeChildType::kColorFilter) return Skia_RuntimeFail("Missing child or incorrect child type");
    if(child) slot=sk_ref_sp(child); else slot=nullptr;
    return true;
}
inline bool Skia_RuntimeSetBlender(SkRuntimeEffectBuilder* builder,const char* name,SkBlender* child) {
    auto slot=builder->child(name?name:"");
    if(!slot.fChild || slot.fChild->type!=SkRuntimeChildType::kBlender) return Skia_RuntimeFail("Missing child or incorrect child type");
    if(child) slot=sk_ref_sp(child); else slot=nullptr;
    return true;
}
inline SkShader* Skia_RuntimeMakeShader(const SkRuntimeEffectBuilder* builder,const SkiaMatrix& local) {
    auto matrix=Skia_ToMatrix(local); auto result=builder->makeShader(&matrix);
    if(!result) Skia_RuntimeFail("Runtime effect cannot create a shader with these inputs");
    return result.release();
}
inline SkColorFilter* Skia_RuntimeMakeColorFilter(const SkRuntimeEffectBuilder* builder) {
    auto result=builder->makeColorFilter();
    if(!result) Skia_RuntimeFail("Runtime effect cannot create a color filter with these inputs");
    return result.release();
}
inline SkBlender* Skia_RuntimeMakeBlender(const SkRuntimeEffectBuilder* builder) {
    auto result=builder->makeBlender();
    if(!result) Skia_RuntimeFail("Runtime effect cannot create a blender with these inputs");
    return result.release();
}
inline SkBlender* Skia_ModeBlender(SkBlendMode mode) { return SkBlender::Mode(mode).release(); }
inline void Skia_BlenderUnref(SkBlender* blender) { if(blender) blender->unref(); }
inline void Skia_SetBlender(SkPaint* paint,SkBlender* blender) { paint->setBlender(sk_ref_sp(blender)); }
inline bool Skia_PaintBlendMode(const SkPaint* paint,SkBlendMode& out) {
    auto mode=paint->asBlendMode(); if(!mode) return false; out=*mode; return true;
}
