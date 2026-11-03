# Shaders and filters

`require dasskia/skia_effects` provides gradients, shaders, path effects, mask
blur, color filters and image filters. It builds on the drawing module and uses
the same C++ implementation on desktop and WebAssembly.

## Resource and error contract

Factories return standard `Result<T?,SkiaError>`. Use `with_shader`,
`with_path_effect`, `with_mask_filter`, `with_color_filter` or `with_image_filter`
with a factory result. A successful result is destructively extracted; the scope
unrefs once after the callback, including on a body Err. A factory Err skips the
body. Scopes accept receiver-first pipes and `skia_scope`/`skia_use` bindings.
They lend a pointer synchronously; the pointer must not escape or be manually
released. A Result by itself is not an owning RAII container.

`set_shader`, `set_path_effect`, `set_mask_filter`, `set_color_filter`, and
`set_image_filter` retain their own references in Paint. Passing null (the default)
clears the corresponding effect; reset_paint clears all effects. Composition also
retains its inputs, so input scopes can end before rendering. Image shaders own
what they need from the source image; color/position/interval/matrix arrays are
copied by Skia during the factory call.

A null **color filter** is identity. A null **image-filter input** denotes the
source graphic; null composed image-filter results are valid pass-through.
Their successful scopes still run when the pointer is null. The raw factories
therefore use a bool status plus output pointer, separating validation errors
from valid null results. Skia_EffectsError copies the last factory diagnostic;
read it immediately on false. Shader/path/mask factories require non-null output.
Fatal allocation behavior follows Skia; no universal recoverable allocation or
drawing-success guarantee is added. Raw pointers keep native lifetime contracts.

## API

| Family | Factory helpers |
| --- | --- |
| Shader | solid_shader, linear_gradient, radial_gradient, sweep_gradient, conical_gradient, image_shader, blend_shader, shader_with_matrix |
| Path | dash_effect, corner_effect, compose_path_effect, sum_path_effect |
| Mask | blur_mask |
| Color | blend_color_filter, matrix_color_filter, lighting_color_filter, compose_color_filter, linear_to_srgb_filter, srgb_to_linear_filter |
| Image | blur_filter, drop_shadow_filter, offset_filter, dilate_filter, erode_filter, color_filter_image, compose_image_filter, blend_image_filter, crop_filter |

- Colors are numeric unpremultiplied ARGB. Gradient colors need at least two
  entries. Optional positions are empty (even spacing) or match the color count,
  finite and nondecreasing within [0,1]. Duplicate stops express hard transitions.
- GradientOptions selects Clamp/Repeat/Mirror/Decal, premultiplied interpolation,
  and a value local_matrix. Local matrices map shader coordinates into canvas
  local coordinates, as in Skia. A singular gradient matrix returns Err.
- Radius/sigma/offset are canvas local units. Sweep start/end angles are degrees
  from positive X, clockwise in the normal top-left coordinate system. Native
  degenerate-gradient behavior is preserved (zero radius or equal sweep angles).
- ImageShaderOptions selects X/Y tiling, SamplingOptions and local_matrix.
  Mipmap sampling does not construct mipmaps. Blend shader arguments are
  destination then source; both must be non-null.
- Dash intervals have even count >=2, finite nonnegative values and positive
  finite sum. Phase is finite. Dashes affect stroked paths/lines. Corner radius
  and mask blur sigma must be finite and positive. Mask blur exposes Normal,
  Solid, Outer and Inner styles, and respect_ctm.
- Color matrices have 20 finite floats: row-major 4x5 RGBA, with normalized
  channel values and offsets (1 means full intensity, not 255).
- Color/path/image composition means outer(inner(source)); path sum combines the
  two independent effect results. Color blending applies the supplied color
  as source over each input pixel using the selected blend mode.
- Image blur sigmas and dilate/erode radii are finite and nonnegative. A drop
  shadow includes the source graphic as well as its shadow. Crop is XYWH with
  finite bounds and nonnegative sizes, and accepts a tile mode. Crop(Decal)
  clips the output; other modes extend it with tiling. Image blend takes
  background then foreground. Null inputs refer to source graphic.
- Attach an image-filter Paint to `with_layer` to filter a group once; attaching
  it to individual draw calls filters each draw separately. Blur kernels/AA can
  differ between raster and GPU; shared API does not promise identical GPU bytes.

## Native inventory

- `Skia_EffectsError`
- `Skia_SolidShader`
- `Skia_LinearGradient`
- `Skia_RadialGradient`
- `Skia_SweepGradient`
- `Skia_ConicalGradient`
- `Skia_ImageShader`
- `Skia_BlendShader`
- `Skia_LocalShader`
- `Skia_ShaderUnref`
- `Skia_SetShader`
- `Skia_DashEffect`
- `Skia_CornerEffect`
- `Skia_ComposePathEffect`
- `Skia_SumPathEffect`
- `Skia_PathEffectUnref`
- `Skia_SetPathEffect`
- `Skia_BlurMask`
- `Skia_MaskFilterUnref`
- `Skia_SetMaskFilter`
- `Skia_BlendColorFilter`
- `Skia_MatrixColorFilter`
- `Skia_ComposeColorFilter`
- `Skia_LightingColorFilter`
- `Skia_LinearToSRGBFilter`
- `Skia_SRGBToLinearFilter`
- `Skia_ColorFilterUnref`
- `Skia_SetColorFilter`
- `Skia_BlurImageFilter`
- `Skia_ShadowImageFilter`
- `Skia_OffsetImageFilter`
- `Skia_DilateImageFilter`
- `Skia_ErodeImageFilter`
- `Skia_ColorImageFilter`
- `Skia_ComposeImageFilter`
- `Skia_BlendImageFilter`
- `Skia_CropImageFilter`
- `Skia_ImageFilterUnref`
- `Skia_SetImageFilter`
