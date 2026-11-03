options gen2
module skia_filter_graph shared public
require dasskia/skia_runtime public
require dasskia/skia_picture public

def public runtime_image_filter(builder : SkRuntimeEffectBuilder?; child_name : string = ""; input : SkImageFilter? = null; sample_radius : float = 0.0) {
    var filter=Skia_RuntimeImageFilter(builder,child_name,input,sample_radius)
    if (filter==null) { return err(skia_error("runtime_image_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public runtime_image_filter(builder : SkRuntimeEffectBuilder?; child_names : array<string>; inputs : array<SkImageFilter const?>; sample_radius : float = 0.0) {
    var filter=Skia_RuntimeImageFilterInputs(builder,child_names,inputs,sample_radius)
    if (filter==null) { return err(skia_error("runtime_image_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public image_source_filter(image : SkImage?; source,destination : float4; sampling : SamplingOptions = SamplingOptions()) {
    var filter=Skia_ImageSourceFilter(image,source,destination,sampling.filter,sampling.mipmap,sampling.cubic,sampling.b,sampling.c)
    if (filter==null) { return err(skia_error("image_source_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public picture_source_filter(picture : SkPicture?; target : float4) {
    var filter=Skia_PictureSourceFilter(picture,target)
    if (filter==null) { return err(skia_error("picture_source_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public shader_source_filter(shader : SkShader?; dither : bool = false) {
    var filter=Skia_ShaderSourceFilter(shader,dither)
    if (filter==null) { return err(skia_error("shader_source_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public merge_filters(inputs : array<SkImageFilter const?>) {
    var filter=Skia_MergeFilters(inputs)
    if (filter==null) { return err(skia_error("merge_filters",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public matrix_transform_filter(transform : SkiaMatrix; input : SkImageFilter? = null; sampling : SamplingOptions = SamplingOptions()) {
    var filter=Skia_MatrixTransformFilter(transform,sampling.filter,sampling.mipmap,sampling.cubic,sampling.b,sampling.c,input)
    if (filter==null) { return err(skia_error("matrix_transform_filter",Skia_RuntimeError()),type<SkImageFilter?>) }
    return <- move_ok(filter,type<SkiaError>)
}
def public image_source_filter(image : SkImage?; destination : float4; sampling : SamplingOptions = SamplingOptions()) {
    var source : float4
    if (image!=null) { let size=image_size(image); source=float4(0.0,0.0,float(size.x),float(size.y)) }
    return <- image_source_filter(image,source,destination,sampling)
}
def public image_source_filter(image : SkImage?; sampling : SamplingOptions = SamplingOptions()) {
    var bounds : float4
    if (image!=null) { let size=image_size(image); bounds=float4(0.0,0.0,float(size.x),float(size.y)) }
    return <- image_source_filter(image,bounds,bounds,sampling)
}
def public picture_source_filter(picture : SkPicture?) {
    var target : float4
    if (picture!=null) { target=picture_stats(picture).cull }
    return <- picture_source_filter(picture,target)
}
