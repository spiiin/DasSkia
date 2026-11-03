# Image processing and lighting filters

`require dasskia/skia_advanced_filters` exposes SkImageFilters factories with
typed SkColorChannel selectors and the shared ImageFilter / Result /
with_image_filter lifetime model.

## Convolution

`convolution_filter(kernel,ConvolutionOptions(),input=null)` applies a row-major
kernel to the input filter, or the source graphic when input is null. Defaults
are a 3x3 kernel, offset (1,1), gain 1, bias 0, Decal tiling, RGB-only convolution,
and no crop. Changing size does not implicitly change the offset.

The adapter checks positive dimensions, exact width*height array size using
uint64 multiplication, offset inside the kernel, finite coefficients/gain/bias,
and valid optional crop bounds before calling Skia. The array is synchronously
copied by Skia. m138 also rejects kernels exceeding 256 elements; the native
rejection is returned as Err. Large-kernel numerical precision and performance
follow Skia's implementation, not an arbitrary-size CPU convolution promise.

Gain multiplies the sum and bias is added in **0..255 channel units** (bias 64 is
about 0.251, not 64 times full intensity). Kernel values/gain are not automatically
normalized. When convolve_alpha=false, alpha is copied from the input; when true,
coverage is filtered with color. This can expand alpha beyond the original shape.

## Displacement, tile and magnifier

`displacement_filter(x,y,scale,displacement,color,crop=FilterCrop())` uses typed
SkColorChannel.R/G/B/A. The displacement input encodes an unpremultiplied vector
centered on 0.5, scaled into local coordinates; the color input is sampled using
that offset. Null for either filter denotes source graphic. Scale must be finite;
negative scale is valid and reverses displacement.

`tile_filter(sourceXYWH,destinationXYWH,input=null)` repeats the source region and
clips to destination. It does not scale the source to fit the destination.
Rectangles must have finite bounds and nonnegative sizes; empty geometry follows
native transparent-output behavior.

`magnifier_filter(lensXYWH,MagnifierOptions(),input=null)` has default zoom 2,
inset 0, nearest SamplingOptions and no crop. Lens must be finite and nonempty,
zoom finite/positive, and inset finite/nonnegative. Native m138 treats zoom <=1 as
a no-op, returning the input (possibly null). The input's actual bounds and the
lens affect the native zoom center/output. Insets blend the transition near the
lens edge; this is not simply a uniform canvas scaling operation.

## Arithmetic and custom blending

`arithmetic_filter(coefficients,background,foreground,enforce_premul=true,crop)`
uses a float4 (k1,k2,k3,k4) and computes, per channel:

```
k1 * foreground * background + k2 * foreground + k3 * background + k4
```

Coefficients must be finite; they need not be nonnegative or sum to one. Native
clamping applies, and enforce_premul clamps RGB to computed alpha when enabled.
Null background/foreground inputs denote source graphic. Native arithmetic
simplifications may return a valid null pass-through result.

`blend_image_filter(blender,background,foreground,crop)` overloads the existing
SkBlendMode helper with SkBlender?. Runtime blenders and mode_blender outputs can
be used; a null blender selects SrcOver. Native Src/Dst simplifications can also
return a valid null input reference. All non-null blender/input refs are retained.

`shadow_only_filter(offset,sigma,color,input=null,crop)` produces just the shadow,
without drawing the original source on top. Offsets must be finite and sigmas
finite/nonnegative. `empty_filter()` makes explicit transparent output, which is
not the same as null/source graphic when passed to another factory.

## Lighting

The six factories are distant_diffuse_filter, point_diffuse_filter,
spot_diffuse_filter, distant_specular_filter, point_specular_filter, and
spot_specular_filter. Distant lights take float3 direction, point lights float3
location, and spot lights location plus target. Coordinates and surface scale
follow native filter-local mapping into layer space.

LightingOptions defaults to white color, surface_scale=1, coefficient=1,
shininess=16, falloff=1, cutoff_degrees=45, and no crop. Coefficient is kd for
diffuse and ks for specular. Shininess applies to specular; falloff/cutoff apply
to spot lights. Used parameters must be finite and coefficient nonnegative,
matching native m138 validation. Direction/target and material choices remain the
caller's mathematical inputs; this is not an SVG document parameter validator.

The **input alpha is a height map**; input RGB is not a surface texture. Surface
scale maps alpha into height before normal estimation. Diffuse lighting produces
opaque illuminated RGB in its output region; specular intensity uses alpha to
preserve premultiplication. Lighting can affect transparent black and is not
implicitly confined to the original shape. Use a crop or output clip to bound it.
The example supplies a radial alpha ramp to show raised diffuse/specular surfaces.

## Native optional crop

FilterCrop has enabled=false and rect=XYWH. Disabled means no native CropRect;
enabled preserves even an empty crop. Finite bounds and nonnegative sizes are
required. This exposes native semantics rather than always adding an outer clip:

- Convolution with non-Decal tiling restricts/tiles input at the crop edges and
  also crops output. Without crop, m138 does not apply the requested tile mode.
  With Decal, the crop limits output. Clamp/Decal edge behavior is tested.
- Lighting crops both input (affecting normal boundary conditions) and output.
- Magnifier crops input; lens/input bounds determine output.
- Displacement, arithmetic, custom blend and shadow use native factory crop
  behavior, generally bounding output. Native implementation details and sampling
  precision remain relevant at boundaries.

For only an output clip, compose an existing crop_filter where appropriate.
For an explicitly tiled upstream input, compose crop_filter with a tile mode.
The native-crop overload and an outer crop are not universally interchangeable.

## Results, ownership and serialization

Raw factories return bool plus an output pointer. This separates rejection from
valid null identity/pass-through results. Boost returns standard Result and
with_image_filter still runs the callback on Ok(null), then safely skips unref.
A factory Err does not run the callback. Paint setters and composition retain
independent references; array/builder/source scopes can end before later drawing.
Existing manual-unref, borrowed-pointer and defer/panic contracts still apply.

Factory acceptance does not promise success/performance for every draw, and fatal
native allocation behavior is unchanged. Filtering remains a native operation on
raster and Ganesh OpenGL / WASM WebGL 2; no new backend or CPU pixel-loop emulation
has been added. Boundary AA, kernel representation and lighting precision can
vary, so functional checks use tolerances where needed.

Filters can be recorded in SkPicture. Convolution and lighting SKP fixtures are
checked in native/WASM in both directions, retaining the pinned-version/profile
limits in picture-api.md. The example is examples/advanced_filters.das.

## Native inventory

| Group | Count | Adapters (Skia_ prefix omitted) |
| --- | ---: | --- |
| Image processing | 8 | EmptyFilter, ConvolutionFilter, DisplacementFilter, ArithmeticFilter, CustomBlendFilter, TileFilter, MagnifierFilter, ShadowOnlyFilter |
| Lighting | 6 | DistantDiffuseFilter, DistantSpecularFilter, PointDiffuseFilter, PointSpecularFilter, SpotDiffuseFilter, SpotSpecularFilter |
