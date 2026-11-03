#pragma once
#include "skia_api.h"
#include "daScript/daScript.h"
#include "include/encode/SkJpegEncoder.h"
#include "include/encode/SkWebpEncoder.h"
#include <cmath>
#include <cstring>
#include <limits>
#include <string>
using SkiaJpegDownsample=SkJpegEncoder::Downsample;
using SkiaJpegAlpha=SkJpegEncoder::AlphaOption;
using SkiaWebpCompression=SkWebpEncoder::Compression;
inline thread_local std::string skia_codec_error;
inline bool Skia_CodecFail(const char* message) {skia_codec_error=message;return false;}
inline char* Skia_CodecError(das::Context* context,das::LineInfoArg* at) {
    return context->allocateString(skia_codec_error.c_str(),uint32_t(skia_codec_error.size()),at);
}
inline bool Skia_CodecPixels(SkSurface* surface,SkPixmap& pixels) {
    if(!surface || !surface->peekPixels(&pixels)) return Skia_CodecFail("Encoding requires CPU-addressable raster pixels");
    return true;
}
inline sk_sp<SkData> Skia_JpegData(SkSurface* surface,int quality,SkiaJpegDownsample downsample,SkiaJpegAlpha alpha) {
    if(quality<0 || quality>100) {Skia_CodecFail("JPEG quality must be in 0..100");return nullptr;}
    if(downsample!=SkiaJpegDownsample::k420 && downsample!=SkiaJpegDownsample::k422 && downsample!=SkiaJpegDownsample::k444) {
        Skia_CodecFail("Invalid JPEG downsampling");return nullptr;
    }
    if(alpha!=SkiaJpegAlpha::kIgnore && alpha!=SkiaJpegAlpha::kBlendOnBlack) {Skia_CodecFail("Invalid JPEG alpha option");return nullptr;}
    SkPixmap pixels;if(!Skia_CodecPixels(surface,pixels)) return nullptr;
    SkJpegEncoder::Options options;options.fQuality=quality;options.fDownsample=downsample;options.fAlphaOption=alpha;
    SkDynamicMemoryWStream stream;
    if(!SkJpegEncoder::Encode(&stream,pixels,options)) {Skia_CodecFail("JPEG encoding failed");return nullptr;}
    return stream.detachAsData();
}
inline sk_sp<SkData> Skia_WebpData(SkSurface* surface,float quality,SkiaWebpCompression compression) {
    if(!std::isfinite(quality) || quality<0 || quality>100) {Skia_CodecFail("WebP quality/effort must be finite and in 0..100");return nullptr;}
    if(compression!=SkiaWebpCompression::kLossy && compression!=SkiaWebpCompression::kLossless) {Skia_CodecFail("Invalid WebP compression mode");return nullptr;}
    SkPixmap pixels;if(!Skia_CodecPixels(surface,pixels)) return nullptr;
    SkWebpEncoder::Options options;options.fQuality=quality;options.fCompression=compression;
    SkDynamicMemoryWStream stream;
    if(!SkWebpEncoder::Encode(&stream,pixels,options)) {Skia_CodecFail("WebP encoding failed");return nullptr;}
    return stream.detachAsData();
}
inline bool Skia_WriteCodecData(sk_sp<SkData> data,const char* path) {
    if(!data) return false;
    if(!path || !*path) return Skia_CodecFail("Output path must not be empty");
    SkFILEWStream stream(path);
    if(!stream.isValid()) return Skia_CodecFail("Cannot open encoded image output");
    if(!stream.write(data->data(),data->size())) return Skia_CodecFail("Cannot write encoded image output");
    stream.flush();
    return stream.bytesWritten()==data->size() || Skia_CodecFail("Incomplete encoded image output");
}
inline bool Skia_CopyCodecData(sk_sp<SkData> data,das::TArray<uint8_t>& bytes,das::Context* context,das::LineInfoArg* at) {
    if(!data) return false;
    if(!data->size() || data->size()>std::numeric_limits<uint32_t>::max()) return Skia_CodecFail("Encoded image exceeds script array limits");
    das::array_resize(*context,bytes,uint32_t(data->size()),sizeof(uint8_t),false,at);
    std::memcpy(bytes.data,data->data(),data->size());return true;
}
inline bool Skia_SaveJpeg(SkSurface* surface,const char* path,int quality,SkiaJpegDownsample downsample,SkiaJpegAlpha alpha) {
    return Skia_WriteCodecData(Skia_JpegData(surface,quality,downsample,alpha),path);
}
inline bool Skia_SaveWebp(SkSurface* surface,const char* path,float quality,SkiaWebpCompression compression) {
    return Skia_WriteCodecData(Skia_WebpData(surface,quality,compression),path);
}
inline bool Skia_EncodeJpeg(SkSurface* surface,int quality,SkiaJpegDownsample downsample,SkiaJpegAlpha alpha,das::TArray<uint8_t>& bytes,das::Context* context,das::LineInfoArg* at) {
    return Skia_CopyCodecData(Skia_JpegData(surface,quality,downsample,alpha),bytes,context,at);
}
inline bool Skia_EncodeWebp(SkSurface* surface,float quality,SkiaWebpCompression compression,das::TArray<uint8_t>& bytes,das::Context* context,das::LineInfoArg* at) {
    return Skia_CopyCodecData(Skia_WebpData(surface,quality,compression),bytes,context,at);
}
inline bool Skia_EncodePng(SkSurface* surface,das::TArray<uint8_t>& bytes,das::Context* context,das::LineInfoArg* at) {
    SkPixmap pixels;if(!Skia_CodecPixels(surface,pixels)) return false;
    SkDynamicMemoryWStream stream;
    if(!SkPngEncoder::Encode(&stream,pixels,{})) return Skia_CodecFail("PNG encoding failed");
    return Skia_CopyCodecData(stream.detachAsData(),bytes,context,at);
}
inline SkImage* Skia_ImageFromBytes(const das::TArray<uint8_t>& bytes) {
    if(!bytes.size || !bytes.data) {Skia_CodecFail("Encoded image bytes must not be empty");return nullptr;}
    auto image=SkImages::DeferredFromEncodedData(SkData::MakeWithCopy(bytes.data,bytes.size));
    if(!image) Skia_CodecFail("Unsupported or invalid encoded image header");
    return image.release();
}
