options gen2
require daslib/defer
module skia_runtime shared public
require dasskia/skia_effects public

struct RuntimeOptions {
    unoptimized : bool = false
}
struct RuntimeUniform {
    name : string
    kind : SkRuntimeUniformType
    count : int
    flags : uint
    offset : uint64
    bytes : uint64
}
struct RuntimeChild {
    name : string
    kind : SkRuntimeChildType
    index : int
}
def public compile_runtime(source : string; kind : SkiaRuntimeKind; settings : RuntimeOptions = RuntimeOptions()) {
    var effect=Skia_CompileRuntime(source,uint(length(source)),kind,settings.unoptimized)
    if (effect==null) { return err(skia_error("compile_runtime",Skia_RuntimeError()),type<SkRuntimeEffect?>) }
    return <- move_ok(effect,type<SkiaError>)
}
def public compile_runtime_shader(source : string; settings : RuntimeOptions = RuntimeOptions()) {
    return <- compile_runtime(source,SkiaRuntimeKind.Shader,settings)
}
def public compile_runtime_color_filter(source : string; settings : RuntimeOptions = RuntimeOptions()) {
    return <- compile_runtime(source,SkiaRuntimeKind.ColorFilter,settings)
}
def public compile_runtime_blender(source : string; settings : RuntimeOptions = RuntimeOptions()) {
    return <- compile_runtime(source,SkiaRuntimeKind.Blender,settings)
}
def public runtime_source(effect : SkRuntimeEffect?) : string { return Skia_RuntimeSource(effect) }
def public runtime_supports(effect : SkRuntimeEffect?; kind : SkiaRuntimeKind) : bool { return Skia_RuntimeSupports(effect,kind) }
def public runtime_uniform_size(effect : SkRuntimeEffect?) : uint64 { return Skia_RuntimeUniformSize(effect) }
def public runtime_uniform_count(effect : SkRuntimeEffect?) : int { return Skia_RuntimeUniformCount(effect) }
def public runtime_child_count(effect : SkRuntimeEffect?) : int { return Skia_RuntimeChildCount(effect) }
def public uniform_info(effect : SkRuntimeEffect?; index : int) {
    var info : RuntimeUniform
    if (!Skia_RuntimeUniformInfo(effect,index,info.kind,info.count,info.flags,info.offset,info.bytes)) { return none(type<RuntimeUniform>) }
    info.name=Skia_RuntimeUniformName(effect,index)
    return some(info)
}
def public child_info(effect : SkRuntimeEffect?; index : int) {
    var info : RuntimeChild
    if (!Skia_RuntimeChildInfo(effect,index,info.kind,info.index)) { return none(type<RuntimeChild>) }
    info.name=Skia_RuntimeChildName(effect,index)
    return some(info)
}
def public find_uniform(effect : SkRuntimeEffect?; name : string) {
    for (i in range(runtime_uniform_count(effect))) {
        let info=uniform_info(effect,i)
        if (unwrap(info).name==name) { return info }
    }
    return none(type<RuntimeUniform>)
}
def public find_child(effect : SkRuntimeEffect?; name : string) {
    for (i in range(runtime_child_count(effect))) {
        let info=child_info(effect,i)
        if (unwrap(info).name==name) { return info }
    }
    return none(type<RuntimeChild>)
}
def private runtime_status(success : bool; operation : string) : SkiaStatus {
    if (!success) { return err(skia_error(operation,Skia_RuntimeError()),type<SkiaUnit>) }
    return skia_ok()
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : float) : SkiaStatus {
    let packed=float4(value,0.0,0.0,0.0)
    return runtime_status(Skia_RuntimeSetFloatVector(builder,name,packed,1),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : float2) : SkiaStatus {
    let packed=float4(value,0.0,0.0)
    return runtime_status(Skia_RuntimeSetFloatVector(builder,name,packed,2),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : float3) : SkiaStatus {
    let packed=float4(value,0.0)
    return runtime_status(Skia_RuntimeSetFloatVector(builder,name,packed,3),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : float4) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetFloatVector(builder,name,value,4),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : int) : SkiaStatus {
    let packed=int4(value,0,0,0)
    return runtime_status(Skia_RuntimeSetIntVector(builder,name,packed,1),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : int2) : SkiaStatus {
    let packed=int4(value,0,0)
    return runtime_status(Skia_RuntimeSetIntVector(builder,name,packed,2),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : int3) : SkiaStatus {
    let packed=int4(value,0)
    return runtime_status(Skia_RuntimeSetIntVector(builder,name,packed,3),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : int4) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetIntVector(builder,name,value,4),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : array<float>) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetFloats(builder,name,value),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : array<int>) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetInts(builder,name,value),"set_uniform {name}")
}
def public set_uniform(builder : SkRuntimeEffectBuilder?; name : string; value : SkiaMatrix) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetMatrix(builder,name,value),"set_uniform {name}")
}
def public set_child(builder : SkRuntimeEffectBuilder?; name : string; child : SkShader?) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetShader(builder,name,child),"set_child {name}")
}
def public set_child(builder : SkRuntimeEffectBuilder?; name : string; child : SkColorFilter?) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetColorFilter(builder,name,child),"set_child {name}")
}
def public set_child(builder : SkRuntimeEffectBuilder?; name : string; child : SkBlender?) : SkiaStatus {
    return runtime_status(Skia_RuntimeSetBlender(builder,name,child),"set_child {name}")
}
def public runtime_shader(builder : SkRuntimeEffectBuilder?; local : SkiaMatrix = matrix()) {
    var result=Skia_RuntimeMakeShader(builder,local)
    if (result==null) { return err(skia_error("runtime_shader",Skia_RuntimeError()),type<SkShader?>) }
    return <- move_ok(result,type<SkiaError>)
}
def public runtime_color_filter(builder : SkRuntimeEffectBuilder?) {
    var result=Skia_RuntimeMakeColorFilter(builder)
    if (result==null) { return err(skia_error("runtime_color_filter",Skia_RuntimeError()),type<SkColorFilter?>) }
    return <- move_ok(result,type<SkiaError>)
}
def public runtime_blender(builder : SkRuntimeEffectBuilder?) {
    var result=Skia_RuntimeMakeBlender(builder)
    if (result==null) { return err(skia_error("runtime_blender",Skia_RuntimeError()),type<SkBlender?>) }
    return <- move_ok(result,type<SkiaError>)
}
def public mode_blender(mode : SkBlendMode) {
    var result=Skia_ModeBlender(mode)
    if (result==null) { return err(skia_error("mode_blender",Skia_RuntimeError()),type<SkBlender?>) }
    return <- move_ok(result,type<SkiaError>)
}
def public set_blender(paint : SkPaint?; blender : SkBlender? = null) { Skia_SetBlender(paint,blender) }
def public paint_blend_mode_option(paint : SkPaint?) {
    var mode : SkBlendMode
    if (!Skia_PaintBlendMode(paint,mode)) { return none(type<SkBlendMode>) }
    return some(mode)
}
def public create_runtime_builder(effect : SkRuntimeEffect?) : SkRuntimeEffectBuilder? { return Skia_NewRuntimeBuilder(effect) }
def public with_runtime_builder(effect : SkRuntimeEffect?; blk : block<(builder : SkRuntimeEffectBuilder?) : $Result<auto(BuilderBodyResult);SkiaError>>) {
    let builder=create_runtime_builder(effect)
    var result : $Result<BuilderBodyResult;SkiaError>
    {
        defer() { Skia_DeleteRuntimeBuilder(builder) }
        static_if (typeinfo can_copy(type<$Result<BuilderBodyResult;SkiaError>>)) { result=blk(builder) } else { result <- blk(builder) }
    }
    return <- result
}
def public with_runtime_effect(var created : $Result<SkRuntimeEffect?;SkiaError>; blk : block<(resource : SkRuntimeEffect?) : $Result<auto(RuntimeBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<RuntimeBodyResult>) }
    let resource=move_unwrap(created)
    var result : $Result<RuntimeBodyResult;SkiaError>
    {
        defer() { Skia_RuntimeUnref(resource) }
        static_if (typeinfo can_copy(type<$Result<RuntimeBodyResult;SkiaError>>)) { result=blk(resource) } else { result <- blk(resource) }
    }
    return <- result
}
def public with_blender(var created : $Result<SkBlender?;SkiaError>; blk : block<(resource : SkBlender?) : $Result<auto(RuntimeBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<RuntimeBodyResult>) }
    let resource=move_unwrap(created)
    var result : $Result<RuntimeBodyResult;SkiaError>
    {
        defer() { Skia_BlenderUnref(resource) }
        static_if (typeinfo can_copy(type<$Result<RuntimeBodyResult;SkiaError>>)) { result=blk(resource) } else { result <- blk(resource) }
    }
    return <- result
}
