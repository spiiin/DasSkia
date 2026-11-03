# Drawing and image transfers

`require dasskia/skia_drawing` provides paints, paths, canvas state, matrices,
image sampling and copied pixels. See [shaders and filters](effects-api.md),
[path geometry](geometry-api.md), [recorded pictures](picture-api.md) and
[image codecs](image-codecs-api.md) for related APIs.

| Group | Count | Native adapters (Skia_ prefix omitted) |
| --- | ---: | --- |
| Paint | 17 | ResetPaint, ClonePaint, GetColor, SetAlpha, GetAlpha, SetBlendMode, GetBlendMode, SetStrokeCap, GetStrokeCap, SetStrokeJoin, GetStrokeJoin, SetStrokeMiter, GetStrokeMiter, GetStrokeWidth, SetPaintStyle, GetPaintStyle, GetAntialias |
| Drawing | 5 | DrawLine, DrawOval, DrawRoundRect, DrawArc, DrawPaint |
| Canvas state | 8 | ClipPath, ClipRectOp, Skew, ConcatMatrix, SetMatrix, GetMatrix, ResetMatrix, SaveLayer |
| Paths | 16 | ClonePath, PathQuadTo, PathConicTo, PathArcTo, PathAddRect, PathAddOval, PathAddRoundRect, PathSetFillType, PathGetFillType, PathContains, PathBounds, PathTightBounds, PathTransform, PathOffset, PathAddPath, PathIsEmpty |
| Matrix values | 5 | MatrixIdentity, MatrixMake, MatrixMultiply, MatrixInvert, MatrixMapPoint |
| Images | 6 | ImageWidth, ImageHeight, ImageSubset, ImageWithMipmaps, DrawImageRect, DrawImageSampled |
| Pixels | 2 | ReadPixelsArgb, WritePixelsArgb |

Nine native enums are exposed with script-friendly labels and native AOT metadata:
SkBlendMode, SkStrokeCap, SkStrokeJoin, SkPaintStyle, SkPathDirection, SkPathFillType,
SkClipOp, SkFilterMode and SkMipmapMode. SkiaMatrix is a POD value adapter containing
nine floats, converted to a native SkMatrix at use sites. No heap ownership is added
to matrix operations.

The public boost functions are in dasskia/skia_drawing.das. Native adapters are
in src/skia_drawing.h; enum and function registration is in
src/skia_drawing_registration.h. Both headers participate in the shared AOT setup.
