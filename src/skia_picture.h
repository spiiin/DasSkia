#pragma once
#include "skia_drawing.h"
#include "include/core/SkBBHFactory.h"
#include "include/core/SkPicture.h"
#include "include/core/SkPictureRecorder.h"
#include "include/core/SkSerialProcs.h"
#include <cmath>
#include <cstring>
#include <limits>

inline bool Skia_PictureBounds(const das::float4& b) {
    return std::isfinite(b.x) && std::isfinite(b.y) && std::isfinite(b.z) && std::isfinite(b.w) &&
           b.z>=0 && b.w>=0 && std::isfinite(b.x+b.z) && std::isfinite(b.y+b.w);
}
inline SkPictureRecorder* Skia_NewPictureRecorder() { return new SkPictureRecorder(); }
inline void Skia_DeletePictureRecorder(SkPictureRecorder* r) { delete r; }
inline SkCanvas* Skia_BeginPictureRecording(SkPictureRecorder* r,const das::float4& bounds,bool bbh) {
    if(r->getRecordingCanvas() || !Skia_PictureBounds(bounds)) return nullptr;
    SkRTreeFactory factory;
    return r->beginRecording(Skia_Rect(bounds),bbh?&factory:nullptr);
}
inline SkCanvas* Skia_PictureRecordingCanvas(SkPictureRecorder* r) { return r->getRecordingCanvas(); }
inline SkPicture* Skia_FinishPicture(SkPictureRecorder* r) {
    return r->getRecordingCanvas()?r->finishRecordingAsPicture().release():nullptr;
}
inline SkPicture* Skia_FinishPictureWithCull(SkPictureRecorder* r,const das::float4& bounds) {
    if(!r->getRecordingCanvas() || !Skia_PictureBounds(bounds)) return nullptr;
    return r->finishRecordingAsPictureWithCull(Skia_Rect(bounds)).release();
}
inline void Skia_PictureUnref(SkPicture* picture) { if(picture) picture->unref(); }
inline das::float4 Skia_PictureCull(const SkPicture* picture) { return Skia_XYWH(picture->cullRect()); }
inline uint32_t Skia_PictureID(const SkPicture* picture) { return picture->uniqueID(); }
inline int Skia_PictureOpCount(const SkPicture* picture,bool nested) { return picture->approximateOpCount(nested); }
inline uint64_t Skia_PictureBytes(const SkPicture* picture) { return uint64_t(picture->approximateBytesUsed()); }
inline void Skia_DrawPicture(SkCanvas* canvas,const SkPicture* picture,const SkiaMatrix& transform,const SkPaint* paint) {
    auto matrix=Skia_ToMatrix(transform); canvas->drawPicture(picture,&matrix,paint);
}
inline void Skia_PlaybackPicture(const SkPicture* picture,SkCanvas* canvas) { picture->playback(canvas); }

// Explicit image encoding catches failures instead of silently writing a missing
// image. Encoded CPU images are reused; other CPU images are encoded as PNG.
// Texture readback needs an external context and is intentionally not implicit.
inline sk_sp<SkData> Skia_EncodePictureImage(SkImage* image,void* state) {
    auto data=image->refEncodedData();
    if(!data) data=SkPngEncoder::Encode(nullptr,image,{});
    if(!data) { *static_cast<bool*>(state)=false; return SkData::MakeEmpty(); }
    return data;
}
inline sk_sp<SkData> Skia_EncodedPicture(const SkPicture* picture) {
    bool success=true; SkSerialProcs procs;
    procs.fImageProc=Skia_EncodePictureImage; procs.fImageCtx=&success;
    auto data=picture->serialize(&procs);
    return success?data:nullptr;
}
inline bool Skia_SerializePicture(const SkPicture* picture,das::TArray<uint8_t>& bytes,das::Context* context,das::LineInfoArg* at) {
    auto data=Skia_EncodedPicture(picture);
    if(!data || data->size()>std::numeric_limits<uint32_t>::max()) return false;
    das::array_resize(*context,bytes,uint32_t(data->size()),sizeof(uint8_t),false,at);
    if(data->size()) std::memcpy(bytes.data,data->data(),data->size());
    return true;
}
inline SkPicture* Skia_DeserializePicture(const das::TArray<uint8_t>& bytes) {
    if(!bytes.size) return nullptr;
    // The input array is never borrowed by deferred images or nested resources.
    auto data=SkData::MakeWithCopy(bytes.data,bytes.size);
    return data?SkPicture::MakeFromData(data.get()).release():nullptr;
}
inline bool Skia_SavePicture(const SkPicture* picture,const char* path) {
    auto data=Skia_EncodedPicture(picture);
    if(!data) return false;
    SkFILEWStream stream(path);
    if(!stream.isValid() || !stream.write(data->data(),data->size())) return false;
    stream.flush(); return stream.bytesWritten()==data->size();
}
inline SkPicture* Skia_LoadPicture(const char* path) {
    auto data=SkData::MakeFromFileName(path);
    return data?SkPicture::MakeFromData(data.get()).release():nullptr;
}
inline SkShader* Skia_PictureShader(const SkPicture* picture,SkTileMode x,SkTileMode y,SkFilterMode filter,
                                   const SkiaMatrix& local,bool customTile,const das::float4& tile) {
    if(customTile && !Skia_PictureBounds(tile)) return nullptr;
    auto matrix=Skia_ToMatrix(local); auto rect=Skia_Rect(tile);
    return picture->makeShader(x,y,filter,&matrix,customTile?&rect:nullptr).release();
}
