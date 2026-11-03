# SkSL runtime effects

`require dasskia/skia_runtime` exposes SkRuntimeEffect, SkRuntimeEffectBuilder
and SkBlender, with typed stage, uniform and child enums. It uses the public
Skia m138 runtime-effect API, which is experimental in Skia.

## Compile once, create snapshots

`compile_runtime_shader`, `compile_runtime_color_filter` and
`compile_runtime_blender` return Result<SkRuntimeEffect?,SkiaError>. The generic
`compile_runtime(source,SkiaRuntimeKind,RuntimeOptions())` also exposes stage
selection. RuntimeOptions.unoptimized enables Skia's testing/debug optimization
switch; it defaults false. Compiler failures copy the native diagnostic into
SkiaError. SkSL braces inside ordinary daScript strings need `\{` and `\}`
escaping; this is a host-string rule, not a different shader language.

Required main signatures are:

```c
half4 main(float2 localCoordinates);                  // shader
half4 main(half4 inputColor);                         // color filter
half4 main(half4 sourceColor, half4 destinationColor); // blender
```

Skia also accepts its documented float4/vec4 aliases for color signatures.
Shader coordinates are local canvas coordinates, not normalized texture UVs.
Skia supplies working-space colors; return premultiplied colors. A color uniform
with `layout(color)` is supplied as unpremultiplied extended-range sRGB and is
transformed by Skia into the working color space. A regular float4 has no such
color conversion. The adapter does not reinterpret numeric ARGB as float colors.

`create_runtime_builder(effect)` returns an owned native builder;
`with_runtime_builder(effect,callback)` is the scoped form. It retains the effect,
zero-initializes uniform storage, and starts with null children. Use named
`set_uniform` and `set_child`, then `runtime_shader(builder,local=matrix())`,
`runtime_color_filter(builder)` or `runtime_blender(builder)` to create a Result
for an immutable native object. Requesting an incompatible output stage returns
Err. Successful creation is native acceptance, not a per-draw success signal.

Built objects own effect, uniform and child references. Builder writes use Skia's
copy-on-write uniform storage; changing a builder later does not change an
existing object. Update uniforms/build a new snapshot to animate. Compiling in
app_init and updating values per frame avoids recompiling source. daScript strict
AOT does not precompile SkSL: Skia still compiles that source at runtime.

## Uniform setters and reflection

`set_uniform(builder,name,value)` supports float/float2/float3/float4,
int/int2/int3/int4, array<float>, array<int>, and SkiaMatrix. The adapters validate
presence, numeric kind and complete size before entering native setters, avoiding
Skia's debug assertions or silent setter failures on mismatched input. Invalid
sets leave the existing value intact and return SkiaStatus Err. Arrays are copied
synchronously; no script storage is borrowed by the builder.

- Scalar/vector overloads require exactly that non-array declaration.
- A flat numeric array sets the entire named uniform, including vector arrays
  or matrices. Element count must match sizeInBytes/4; there is no implicit
  int/float conversion, partial update or array resizing inside SkSL.
- Half uniforms use float storage on the host. Integer storage is signed int32.
- Raw matrix arrays are **column-major**. SkiaMatrix's row-major POD is accepted
  only for one float3x3; the native adapter transposes its storage into SkSL's
  convention. float2x2/float4x4 and matrix arrays use flat arrays.
- Values retain native floating-point semantics; finite/range/color validity is
  the shader author's responsibility. The setters check layout/type, not the
  mathematical domain of every expression in arbitrary source.

`runtime_uniform_count`, `runtime_uniform_size`, `uniform_info(effect,index)` and
`find_uniform(effect,name)` expose reflected metadata. Info/lookup returns
Option<RuntimeUniform> with copied name, SkRuntimeUniformType, element count,
flags and uint64 byte offset/size. Flags preserve native Array (1), Color (2) and
HalfPrecision (16), including any other native bits. This metadata is for
inspection; no raw byte-layout writer or borrowed Uniform pointer is exposed.
Bounds/missing names yield None. `runtime_source` returns copied source text and
`runtime_supports(effect,SkiaRuntimeKind)` reports native allowed stages.

## Children and blenders

`set_child` accepts typed SkShader?, SkColorFilter? and SkBlender? pointers. The
name and declared child kind must match, even when clearing a slot. Assignments
retain references. With overloads, use a typed null variable to clear a particular
child kind. Native null child semantics are transparent black for shader, identity
for colorFilter, and source-over for blender.

`runtime_child_count`, `child_info(effect,index)` and `find_child(effect,name)`
return copied RuntimeChild metadata (name, SkRuntimeChildType and native index),
with Option absence for bad indices/names. SkSL evaluates children using `.eval`:
shader.eval(coords), colorFilter.eval(color), blender.eval(src,dst).

`mode_blender(SkBlendMode)` creates an owned enum blender, useful as a child.
`with_blender` scopes its Result or a runtime blender Result. `set_blender(paint,
blender=null)` retains a reference; null restores SrcOver. The existing
set_blend_mode overrides a custom blender with a standard enum implementation.
`paint_blend_mode_option` returns Some(mode) when native asBlendMode can represent
the Paint, otherwise None. The older paint_blend_mode intentionally retains its
SrcOver fallback when no enum representation exists; use the Option query for
custom blenders.

## Ownership and portability

Use with_runtime_effect for a compiler Result, with_runtime_builder for a builder,
and existing with_shader/with_color_filter/with_blender for output objects.
Scopes lend pointers synchronously and preserve body Err. Factory Err skips the
scope body. Manual cleanup uses Skia_RuntimeUnref, Skia_DeleteRuntimeBuilder,
Skia_BlenderUnref and the existing shader/filter unref functions. Paint retains
its output independently, so all creation scopes can close before drawing.
Result itself is not RAII, and pointers must not escape their lending scopes.
The existing defer/panic and fatal native allocation limits still apply.

The compiler uses Skia's public ES2 runtime-effect restrictions on native raster,
Ganesh OpenGL and WASM/WebGL 2. Private-access and ES3 max-version switches are not
exposed. This is SkSL, with Skia pipeline/child semantics, rather than a raw GPU
program API. Backend math precision, filtering and AA can differ; an arbitrary
accepted program is not a promise of identical bytes or bounded execution cost
on every backend. Runtime image filters are exposed by [filter-graph-api.md](filter-graph-api.md);
traces and mesh effects remain outside this API. Keep complex shader performance work separate from functional validation.

Runtime shaders can be recorded/serialized in SkPicture; Skia serializes their
source, uniforms and children. They are recompiled when loading, so SKP keeps the
same pinned-version/profile restrictions documented in picture-api.md.

## Native inventory

| Family | Count | Adapters (Skia_ prefix omitted) |
| --- | ---: | --- |
| Compile/effect/reflection | 12 | RuntimeError, CompileRuntime, RuntimeUnref, RuntimeSource, RuntimeSupports, RuntimeUniformSize, RuntimeUniformCount, RuntimeChildCount, RuntimeUniformInfo, RuntimeUniformName, RuntimeChildInfo, RuntimeChildName |
| Builder lifetime | 2 | NewRuntimeBuilder, DeleteRuntimeBuilder |
| Uniforms | 5 | RuntimeSetFloats, RuntimeSetInts, RuntimeSetFloatVector, RuntimeSetIntVector, RuntimeSetMatrix |
| Children | 3 | RuntimeSetShader, RuntimeSetColorFilter, RuntimeSetBlender |
| Build outputs | 3 | RuntimeMakeShader, RuntimeMakeColorFilter, RuntimeMakeBlender |
| Blender/Paint | 4 | ModeBlender, BlenderUnref, SetBlender, PaintBlendMode |
