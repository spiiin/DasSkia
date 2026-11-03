# Runtime image filters and filter graphs

`require dasskia/skia_filter_graph` connects SkRuntimeEffectBuilder to native
SkImageFilters factories. Filters use Skia ownership and composition semantics.

## Bind a runtime shader to image-filter inputs

`runtime_image_filter(builder,child_name="",input=null,sample_radius=0)` returns
Result<SkImageFilter?,SkiaError>. The builder must allow the shader stage.
The named child must be a declared `uniform shader`. Empty name uses native
automatic binding only when the effect has exactly one child declaration, which
must be a shader. With other child declarations, specify the name explicitly.

The input filter's output becomes that shader's `.eval(coords)` source. A null
input denotes the implicit source graphic. Other builder children remain static;
a binding overrides any shader already assigned to that slot in the copied
builder, without changing the caller's builder. Uniforms, static children and
input references are retained as a snapshot. Later builder changes do not change
an existing filter. Use existing with_image_filter/set_image_filter scopes and
Paint ownership; there is no separate runtime-filter lifetime system.

For multiple inputs use the overload taking `array<string> child_names` and
`array<SkImageFilter const?> inputs`. Arrays must have equal length, names must be
nonempty, unique and refer to declared shader children. Each null filter entry
means the source graphic. Explicit empty arrays make a zero-dynamic-input leaf,
which can evaluate a procedural/static-child shader independently of the source.

The arrays borrow resource pointers and do not own references themselves. Build
them within the sources' lending scopes. The factory synchronously copies names
and retains input filters; arrays and source scopes can then end before rendering.
Use typed readonly pointers so scoped resources can be passed without discarding
const. The pinned daScript pointer factory also puts const on the pointer value;
the two native array registrations normalize that outer qualifier in addExtern's
callback before mangling. Pointees and the array parameters remain readonly.
Strict AOT is checked separately; no dependency source was changed for this.

## Sampling radius, bounds and groups

sample_radius is a finite nonnegative bound on the maximum absolute X or Y offset
between the main shader coordinate and every sample of a dynamically bound child.
For example, sampling p+float2(8,0) needs radius >=8. Multiple inputs share the
same maximum radius. The adapter rejects negative/NaN/infinite radii but cannot
infer a bound from arbitrary SkSL or changing uniforms.

The radius expands the required input region, including beyond the output clip.
It does **not** clamp coordinates, add a blur, or validate the algorithm's actual
sampling behavior. Under-declaring the radius violates Skia's input-region
assumption. Coordinates are in the filter's local system and follow the native
canvas mapping. In m138 runtime image filters use a translate-only evaluation
layer before some transforms; scaling/rotation can resample that result rather
than evaluate arbitrary shaders directly at final device resolution.

Runtime filters can affect transparent black and report unbounded potential
output. Use crop_filter or an explicit canvas clip when output must be bounded.
They do not inherit source geometry as an implicit output crop. with_layer with
an image-filter Paint processes the complete group once on restore. Individual
draws inside should use an ordinary Paint unless additional filtering is intended.
Attaching a filter to each separate draw processes each source separately.

## Native source and composition factories

| Helper | Behavior |
| --- | --- |
| image_source_filter(image,src,dst,sampling) | Draw an image subset into destination XYWH; overloads use full image/natural bounds. |
| picture_source_filter(picture,target) | Draw a picture clipped to target XYWH and its cull rect. The target is a clip, not a fit/scale rectangle. Default target is picture cull. |
| shader_source_filter(shader,dither=false) | Fill requested output from a shader; use crop_filter to bound a procedural source. |
| merge_filters(inputs) | Composite inputs in array order with SrcOver; later inputs draw over earlier ones. |
| matrix_transform_filter(matrix,input=null,sampling) | Transform filter-local content before the destination canvas transform. |

Input references are retained; returned objects are native immutable filters.
Rectangles need finite coordinates/bounds and nonnegative sizes. Source rectangles
partially outside an image follow Skia's proportional clipping behavior; empty
rectangles produce transparent output. SamplingOptions has its existing nearest/
linear/mipmap/cubic semantics; cubic B/C must be finite within [0,1]. Mipmap choice
does not itself promise creation of missing mipmaps. Matrix transforms must be
finite and invertible; invalid/singular matrices return Err rather than being
mistaken for an identity/null-input filter.

Null **Image/Picture/Shader leaf objects** produce successful, non-null filters
that evaluate transparent black. An empty merge is also explicit transparent
output. This differs from a null **input filter**, which means source graphic.
The empty objects preserve this distinction when chained into another filter.
Factories return Err only on adapter validation or native factory rejection;
draw calls retain their ordinary void/native acceptance contract.

## Serialization and example

These filters can be attached to a recorded Paint/SkPicture. Skia serializes the
runtime source, uniform snapshot, names, static children and input filters.
Loading recompiles SkSL and retains the same pinned-version/profile restrictions
as picture-api.md. Both native-to-WASM and WASM-to-native graph fixtures are
checked; this is not a general SKP compatibility guarantee across Skia versions.

examples/filter_graph.das shows source-group processing with an animated sampling
offset, two named inputs, and merged/transformed Picture, Image and Shader sources.
Its two SkSL programs compile at initialization; per-frame updates build new
filter snapshots from the retained builder. Native raster and Ganesh OpenGL /
WASM WebGL 2 use the same script API; backend precision and resampling can differ.
The existing scope/panic and native fatal-allocation limitations remain unchanged.

## Native inventory

- Skia_RuntimeImageFilter
- Skia_RuntimeImageFilterInputs
- Skia_ImageSourceFilter
- Skia_PictureSourceFilter
- Skia_ShaderSourceFilter
- Skia_MergeFilters
- Skia_MatrixTransformFilter
