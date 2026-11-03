#pragma once
#include "daScript/daScript.h"
#include "skia_api.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMetrics.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkTextBlob.h"
#include "include/ports/SkFontMgr_empty.h"
#include "modules/skshaper/include/SkShaper.h"
#include "modules/skshaper/include/SkShaper_harfbuzz.h"
#include "modules/skshaper/include/SkShaper_skunicode.h"
#include "modules/skunicode/include/SkUnicode_icu.h"
#include "src/base/SkUTF.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>
#include <memory>
#include <string>
#include <vector>

inline thread_local std::string skia_text_error;
inline char* Skia_TextError(das::Context* context,das::LineInfoArg* at) {
    return context->allocateString(skia_text_error.c_str(),uint32_t(skia_text_error.size()),at);
}
inline SkFont* Skia_LoadFont(const char* path,float size) {
    if(!std::isfinite(size) || size<=0 || size>4096) {
        skia_text_error="Font size must be finite and in (0,4096]"; return nullptr;
    }
    // FreeType on every platform. Never search OS-installed fonts implicitly.
    auto manager=SkFontMgr_New_Custom_Empty();
    auto face=manager ? manager->makeFromFile(path) : nullptr;
    if(!face) { skia_text_error="Cannot load font file (missing, unreadable or unsupported)"; return nullptr; }
    auto font=std::make_unique<SkFont>(std::move(face),size);
    font->setEdging(SkFont::Edging::kAntiAlias);
    font->setHinting(SkFontHinting::kNone);
    font->setLinearMetrics(true);
    font->setSubpixel(true);
    return font.release();
}
inline void Skia_DeleteFont(SkFont* font) { delete font; }
inline void Skia_FontMetrics(SkFont* font,float& ascent,float& descent,float& leading) {
    SkFontMetrics m; font->getMetrics(&m); ascent=m.fAscent; descent=m.fDescent; leading=m.fLeading;
}
struct SkiaGlyph {
    uint32_t glyph=0,cluster=0,level=0;
    SkPoint position{0,0};
};
// A language adapter for an immutable SkTextBlob and the accompanying shaping
// results. The blob owns font/typeface references; no input string/font escapes.
struct SkiaText {
    sk_sp<SkTextBlob> blob;
    std::vector<SkiaGlyph> glyphs;
    float width=0,height=0;
    int lines=0,missing=0;
};
class SkiaTextHandler final : public SkShaper::RunHandler {
public:
    explicit SkiaTextHandler(SkiaText& text): output(text) {}
    size_t byteOffset=0;
    void beginLine() override { pen={0,output.height}; ascent=descent=leading=lineWidth=0; }
    void runInfo(const RunInfo& info) override {
        SkFontMetrics m; info.fFont.getMetrics(&m);
        ascent=std::min(ascent,m.fAscent); descent=std::max(descent,m.fDescent);
        leading=std::max(leading,m.fLeading); lineWidth+=info.fAdvance.x();
    }
    void commitRunInfo() override { pen.fY-=ascent; }
    Buffer runBuffer(const RunInfo& info) override {
        auto& run=builder.allocRunPos(info.fFont,int(info.glyphCount));
        glyphBuffer=run.glyphs; pointBuffer=run.points();
        clusters.resize(info.glyphCount);
        return {glyphBuffer,pointBuffer,nullptr,clusters.data(),pen};
    }
    void commitRunBuffer(const RunInfo& info) override {
        for(size_t i=0;i<info.glyphCount;++i) {
            output.glyphs.push_back({uint32_t(glyphBuffer[i]),uint32_t(byteOffset+clusters[i]),
                uint32_t(info.fBidiLevel),pointBuffer[i]});
            if(!glyphBuffer[i]) ++output.missing;
        }
        pen+=info.fAdvance;
    }
    void commitLine() override {
        output.width=std::max(output.width,lineWidth);
        output.height+=descent+leading-ascent; ++output.lines;
    }
    void emptyLine(const SkFont& font) {
        SkFontMetrics m; font.getMetrics(&m);
        output.height+=m.fDescent+std::max(0.0f,m.fLeading)-m.fAscent; ++output.lines;
    }
    sk_sp<SkTextBlob> finish() { return builder.make(); }
private:
    SkiaText& output;
    SkTextBlobBuilder builder;
    std::vector<uint32_t> clusters;
    SkGlyphID* glyphBuffer=nullptr;
    SkPoint* pointBuffer=nullptr;
    SkPoint pen{0,0};
    float ascent=0,descent=0,leading=0,lineWidth=0;
};
inline SkiaText* Skia_ShapeText(SkFont* font,const char* utf8,uint32_t bytes,
        float width,bool leftToRight,const char* language,bool ligatures,bool kerning) {
    if(bytes>1024*1024 || !std::isfinite(width) || width<=0) {
        skia_text_error="Text must be at most 1 MiB and wrap width must be finite and positive"; return nullptr;
    }
    if(SkUTF::CountUTF8(utf8,bytes)<0 || (bytes && std::memchr(utf8,0,bytes))) {
        skia_text_error="Text must be valid UTF-8 without embedded NUL"; return nullptr;
    }
    auto result=std::make_unique<SkiaText>();
    if(!bytes) return result.release();
    auto unicode=SkUnicodes::ICU::Make();
    if(!unicode) { skia_text_error="Cannot initialize ICU Unicode services (check icudtl.dat on Windows)"; return nullptr; }
    auto shaper=SkShapers::HB::ShapeThenWrap(unicode,nullptr);
    if(!shaper) { skia_text_error="Cannot initialize HarfBuzz shaper"; return nullptr; }
    SkiaTextHandler handler(*result);
    // ICU handles bidi/script boundaries within each paragraph. Split hard
    // newlines explicitly: SkShaper wraps runs, it is not a paragraph framework.
    size_t offset=0;
    while(offset<=bytes) {
        const char* start=utf8+offset;
        const char* nl=static_cast<const char*>(std::memchr(start,'\n',bytes-offset));
        size_t length=nl?size_t(nl-start):bytes-offset;
        if(length && start[length-1]=='\r') --length;
        if(!length) {
            handler.emptyLine(*font);
        } else {
            SkShaper::TrivialFontRunIterator fonts(*font,length);
            auto bidi=SkShapers::unicode::BidiRunIterator(unicode,start,length,leftToRight?0:1);
            auto script=SkShapers::HB::ScriptRunIterator(start,length);
            SkShaper::TrivialLanguageRunIterator languages(language,length);
            if(!bidi || !script) { skia_text_error="Cannot create Unicode run iterators"; return nullptr; }
            SkShaper::Feature features[]={
                {SkSetFourByteTag('l','i','g','a'),ligatures?1u:0u,0,length},
                {SkSetFourByteTag('c','l','i','g'),ligatures?1u:0u,0,length},
                {SkSetFourByteTag('k','e','r','n'),kerning?1u:0u,0,length}};
            handler.byteOffset=offset;
            int previous=result->lines;
            shaper->shape(start,length,fonts,*bidi,*script,languages,features,3,width,&handler);
            if(result->lines==previous) { skia_text_error="Shaper produced no lines (Unicode break data unavailable)"; return nullptr; }
        }
        if(!nl) break;
        offset=size_t(nl-utf8)+1;
    }
    result->blob=handler.finish();
    return result.release();
}
inline void Skia_DeleteText(SkiaText* text) { delete text; }
inline int Skia_TextGlyphCount(SkiaText* text) { return int(text->glyphs.size()); }
inline int Skia_TextLineCount(SkiaText* text) { return text->lines; }
inline int Skia_TextMissingGlyphs(SkiaText* text) { return text->missing; }
inline float Skia_TextWidth(SkiaText* text) { return text->width; }
inline float Skia_TextHeight(SkiaText* text) { return text->height; }
inline bool Skia_TextGlyph(SkiaText* text,int index,uint32_t& glyph,uint32_t& cluster,
        float& x,float& y,uint32_t& level) {
    if(index<0 || size_t(index)>=text->glyphs.size()) return false;
    auto& g=text->glyphs[size_t(index)]; glyph=g.glyph; cluster=g.cluster;
    x=g.position.x(); y=g.position.y(); level=g.level; return true;
}
inline void Skia_DrawText(SkCanvas* canvas,SkiaText* text,float x,float y,const SkPaint* paint) {
    if(text->blob) canvas->drawTextBlob(text->blob,x,y,*paint);
}
