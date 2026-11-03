options gen2
require daslib/defer
module skia_picture shared public
require dasskia/skia_effects public

struct PictureOptions {
    bounds : float4 = float4(0.0,0.0,800.0,600.0)
    bbh : bool = false
}
struct PictureShaderOptions {
    tile_x : SkTileMode = SkTileMode.Repeat
    tile_y : SkTileMode = SkTileMode.Repeat
    filter : SkFilterMode = SkFilterMode.Linear
    local_matrix : SkiaMatrix = matrix()
    custom_tile : bool = false
    tile : float4
}
struct PictureStats {
    cull : float4
    id : uint
    operations : int
    bytes : uint64
}

def public begin_recording(recorder : SkPictureRecorder?; settings : PictureOptions = PictureOptions()) {
    var recording=Skia_BeginPictureRecording(recorder,settings.bounds,settings.bbh)
    if (recording==null) { return err(skia_error("begin_recording","Recorder is active or bounds are invalid"),type<SkCanvas?>) }
    return <- move_ok(recording,type<SkiaError>)
}
// Borrowed; null when inactive. Invalidated by finish or recorder destruction.
def public recording_canvas(recorder : SkPictureRecorder?) : SkCanvas? { return Skia_PictureRecordingCanvas(recorder) }

def public finish_recording(recorder : SkPictureRecorder?) {
    var picture=Skia_FinishPicture(recorder)
    if (picture==null) { return err(skia_error("finish_recording","Recorder is not active or finishing failed"),type<SkPicture?>) }
    return <- move_ok(picture,type<SkiaError>)
}

def public finish_recording(recorder : SkPictureRecorder?; cull : float4) {
    var picture=Skia_FinishPictureWithCull(recorder,cull)
    if (picture==null) { return err(skia_error("finish_recording","Recorder is not active, cull is invalid, or finishing failed"),type<SkPicture?>) }
    return <- move_ok(picture,type<SkiaError>)
}

def public picture_from_bytes(bytes : array<uint8>) {
    var picture=Skia_DeserializePicture(bytes)
    if (picture==null) { return err(skia_error("picture_from_bytes","Cannot decode picture bytes"),type<SkPicture?>) }
    return <- move_ok(picture,type<SkiaError>)
}

def public load_picture(path : string) {
    var picture=Skia_LoadPicture(path)
    if (picture==null) { return err(skia_error("load_picture","Missing, unreadable or invalid picture file"),type<SkPicture?>) }
    return <- move_ok(picture,type<SkiaError>)
}

def public picture_stats(picture : SkPicture?; nested : bool = false) : PictureStats {
    return PictureStats(cull=Skia_PictureCull(picture),id=Skia_PictureID(picture),
        operations=Skia_PictureOpCount(picture,nested),bytes=Skia_PictureBytes(picture))
}
def public draw_picture(canvas : SkCanvas?; picture : SkPicture?; transform : SkiaMatrix = matrix(); paint : SkPaint? = null) {
    Skia_DrawPicture(canvas,picture,transform,paint)
}
// Replays individual commands; draw_picture retains a nested picture when recording.
def public playback_picture(picture : SkPicture?; canvas : SkCanvas?) { Skia_PlaybackPicture(picture,canvas) }
def public serialize_picture(picture : SkPicture?) {
    var bytes : array<uint8>
    if (!Skia_SerializePicture(picture,bytes)) { return err(skia_error("serialize_picture","Picture/image encoding failed or data exceeds array capacity"),type<array<uint8>>) }
    return <- move_ok(bytes,type<SkiaError>)
}
def public save_picture(picture : SkPicture?; path : string) : SkiaStatus {
    if (!Skia_SavePicture(picture,path)) { return err(skia_error("save_picture","Picture/image encoding or file write failed"),type<SkiaUnit>) }
    return skia_ok()
}
def public picture_shader(picture : SkPicture?; settings : PictureShaderOptions = PictureShaderOptions()) {
    var shader=Skia_PictureShader(picture,settings.tile_x,settings.tile_y,settings.filter,settings.local_matrix,settings.custom_tile,settings.tile)
    if (shader==null) { return err(skia_error("picture_shader","Invalid tile bounds or shader creation failed"),type<SkShader?>) }
    return <- move_ok(shader,type<SkiaError>)
}
def public record_picture(settings : PictureOptions; blk : block<(canvas : SkCanvas?) : SkiaStatus>) {
    let recorder=Skia_NewPictureRecorder()
    {
        defer() { Skia_DeletePictureRecorder(recorder) }
        var begun <- begin_recording(recorder,settings)
        if (is_err(begun)) { return err(unwrap_err(begun),type<SkPicture?>) }
        let canvas=move_unwrap(begun)
        let body=blk(canvas)
        if (is_err(body)) { return err(unwrap_err(body),type<SkPicture?>) }
        return <- finish_recording(recorder)
    }
}
def public with_picture_recorder(blk : block<(recorder : SkPictureRecorder?) : $Result<auto(RecorderBodyResult);SkiaError>>) {
    let recorder=Skia_NewPictureRecorder()
    var result : $Result<RecorderBodyResult;SkiaError>
    {
        defer() { Skia_DeletePictureRecorder(recorder) }
        static_if (typeinfo can_copy(type<$Result<RecorderBodyResult;SkiaError>>)) { result=blk(recorder) } else { result <- blk(recorder) }
    }
    return <- result
}
def public with_picture(var created : $Result<SkPicture?;SkiaError>; blk : block<(picture : SkPicture?) : $Result<auto(PictureBodyResult);SkiaError>>) {
    if (is_err(created)) { return err(unwrap_err(created),type<PictureBodyResult>) }
    let picture=move_unwrap(created)
    var result : $Result<PictureBodyResult;SkiaError>
    {
        defer() { Skia_PictureUnref(picture) }
        static_if (typeinfo can_copy(type<$Result<PictureBodyResult;SkiaError>>)) { result=blk(picture) } else { result <- blk(picture) }
    }
    return <- result
}
