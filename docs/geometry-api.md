# Path geometry

`require dasskia/skia_geometry` provides path boolean operations, SkPathMeasure
and SkOpBuilder. Desktop and WebAssembly share the pinned Skia implementation.

## Paths and operations

`path_op(a,b,operation)` returns Result<SkPath?,SkiaError>. SkPathOp has Union,
Intersect, Difference (a minus b), ReverseDifference (b minus a) and Xor. The
result is a new owned path; input paths remain unchanged. Empty geometric results
are successful allocated empty paths, not null errors. Op works on filled areas,
including the path's fill rule, rather than stroke centerlines. Skia may reduce
curve order and change contour representation without changing the filled area.

`simplify_path` reduces overlapping contours to non-overlapping filled geometry.
`path_as_winding` converts the fill rule to winding, but retains Skia's important
precondition: its inputs must not have self-crossing or crossing contours. Native
AsWinding does not detect every violation and may return success with a changed
area. Simplify such geometry first when an equivalent winding region is needed.
`path_finite` reports finite geometry; operations reject non-finite input paths.

Use `with_path_builder()` for SkOpBuilder. `path_builder_add(builder,path,op)`
copies the path value; the first operand is an empty path. The default operation
is Union. `resolve_path` returns an owned path and resets the builder; native
resolution can fail. Add is a void native operation and does not promise success
of the eventual resolve. This batch API is especially useful for many unions.

`fill_path_with_paint(path,paint,precision=1)` returns filled geometry for the
Paint's stroke/fill style, caps, joins, miter and path effect. It does not bake
shaders, colors, mask/image filters or device-space AA into geometry. Hairlines
cannot be represented by a filled outline and return Err. Precision must be
finite/positive; larger values improve curve subdivision precision at a cost.

## SVG path data

`path_from_svg(data)` parses SVG path data into a new path. It accepts Skia's
absolute/relative commands, including arcs. Invalid syntax or non-finite output
returns Err; empty input produces a successful empty path. `path_to_svg(path,
relative=false)` returns Result<string,SkiaError> with copied script-owned text.

This is geometry serialization, not an SVG document renderer. Paint, CSS,
fill-rule/inverse fill, transform attributes and external assets are not encoded.
Keep fill-rule metadata separately and restore it explicitly. Curves may be
normalized or approximated (e.g. conics), and text/float representation is not a
byte-preserving or universally exact geometry roundtrip.

## Contour measurement

`create_path_measure(path,PathMeasureOptions(force_closed=false,precision=1))`
returns an owned SkPathMeasure. It copies needed geometry, so the source path
can be changed or released afterwards. There is no borrowed live path link.
Precision must be finite/positive; path length and curve positions are numerical
approximations, not exact symbolic arc lengths.

- `measure_length` and `measure_closed` describe the **current contour**.
- `next_contour` advances and returns bool; zero-length contours are skipped by
  Skia. At the end, length is zero, closed is false, and sampling has no value.
- `sample_path(measure,distance)` returns Option<PathSample>, containing position
  and normalized tangent. Finite distance is clamped to [0,current length].
  Empty/zero-length/exhausted contours or a non-finite distance yield None.
- `measure_matrix(measure,distance,position=true,tangent=true)` similarly returns
  Option<SkiaMatrix>. Position translates the origin to the sample; tangent rotates
  the positive X axis into the sampled direction. Either component can be omitted.
- `measure_segment(measure,start,stop)` returns Result<SkPath?,SkiaError> for a
  new path starting with moveTo. Both distances must be finite and are clamped
  to the current contour. The clamped start must be strictly less than stop;
  empty/reversed intervals return Err. It never appends to an existing path.
- `set_measure_path(measure,path=null,force_closed=false)` resets to the first
  measurable contour; null clears the measure. Non-finite input returns Err and
  preserves current measure state. This follows native setPath: precision resets
  to 1 in m138. Create a new measure when another precision is needed.

m138's implementation can report true for a segment with equal distances despite
its header saying zero-length segments return false. The adapter explicitly
checks the nonempty clamped interval before invoking getSegment.

## Ownership and scopes

Use `factory(...) |> with_path()`, `create_path_measure(...) |> with_path_measure()`
and `with_path_builder()`. The Result overload of with_path coexists with the
existing empty-path with_path(). Factories returning pointers produce owned
resources; Result itself is not an RAII owner. The Result scopes destructively
extract a successful result, lend it for the synchronous callback, and delete it
once afterwards, including after body Err. Factory Err skips the body.

With manual ownership use Skia_DeletePath, Skia_DeletePathMeasure and
Skia_DeletePathBuilder. Scope pointers must not escape or be deleted manually.
Panic cleanup has the existing defer limits. Native pointer liveness remains a
caller contract; there is no static borrow checker or recoverable allocation
promise. No new backend is required for geometry: GPU canvases can draw the same
result paths as raster canvases.

## Native inventory

| Family | Count | Adapters (Skia_ prefix omitted) |
| --- | ---: | --- |
| Geometry | 7 | PathOp, PathSimplify, PathAsWinding, PathIsFinite, PathFromSvg, PathToSvg, PathFillWithPaint |
| Measure | 9 | NewPathMeasure, DeletePathMeasure, PathMeasureSetPath, PathMeasureLength, PathMeasureIsClosed, PathMeasureNext, PathMeasurePosTan, PathMeasureMatrix, PathMeasureSegment |
| Builder | 4 | NewPathBuilder, DeletePathBuilder, PathBuilderAdd, PathBuilderResolve |
