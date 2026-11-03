#pragma once
#include "skia_text.h"
#include "modules/skparagraph/include/Paragraph.h"
#include "modules/skparagraph/include/ParagraphBuilder.h"
#include "modules/skparagraph/include/TypefaceFontProvider.h"

using SkiaTextHeightBehavior=skia::textlayout::TextHeightBehavior;
using SkiaTextDecorationStyle=skia::textlayout::TextDecorationStyle;
using SkiaTextDecorationMode=skia::textlayout::TextDecorationMode;
using SkiaParagraphStrut=skia::textlayout::StrutStyle;
using SkiaPlaceholderAlignment=skia::textlayout::PlaceholderAlignment;
using SkiaTextBaseline=skia::textlayout::TextBaseline;
using SkiaParagraphAffinity=skia::textlayout::Affinity;
using SkiaParagraphRectHeight=skia::textlayout::RectHeightStyle;
using SkiaParagraphRectWidth=skia::textlayout::RectWidthStyle;
using SkiaParagraphAlign=skia::textlayout::TextAlign;
using SkiaParagraphDirection=skia::textlayout::TextDirection;
using SkiaParagraphTextStyle=skia::textlayout::TextStyle;
namespace skia_paragraph=skia::textlayout;

inline thread_local std::string skia_paragraph_error;
inline bool Skia_ParagraphFail(const char* message) { skia_paragraph_error=message; return false; }
inline char* Skia_ParagraphError(das::Context* context,das::LineInfoArg* at) {
    return context->allocateString(skia_paragraph_error.c_str(),uint32_t(skia_paragraph_error.size()),at);
}
// FontCollection retains its provider, builders and paragraphs retain the collection.
// Seal when first used: cached paragraphs cannot see subsequent font mutations.
struct SkiaParagraphFonts {
    sk_sp<skia_paragraph::TypefaceFontProvider> provider=sk_make_sp<skia_paragraph::TypefaceFontProvider>();
    sk_sp<skia_paragraph::FontCollection> collection=sk_make_sp<skia_paragraph::FontCollection>();
    bool sealed=false;
    SkiaParagraphFonts() { collection->setAssetFontManager(provider); collection->disableFontFallback(); }
};
struct SkiaParagraphBuilder {
    std::unique_ptr<skia_paragraph::ParagraphBuilder> value;
    std::string text;
    size_t bytes=0;
    int utf16Units=0;
    unsigned depth=0;
};
struct SkiaParagraph {
    std::unique_ptr<skia_paragraph::Paragraph> value;
    std::vector<skia_paragraph::LineMetrics> lines;
    // Only Unicode scalar boundaries are mapped. Interior UTF-8 bytes and the
    // middle of a UTF-16 surrogate pair stay -1; neither conversion rounds.
    std::vector<int32_t> utf8To16,utf16To8,graphemes;
    bool laidOut=false;
};
inline SkiaParagraphFonts* Skia_NewParagraphFonts() { return new SkiaParagraphFonts; }
inline void Skia_DeleteParagraphFonts(SkiaParagraphFonts* fonts) { delete fonts; }
inline bool Skia_ParagraphAddFontFace(SkiaParagraphFonts* fonts,const char* path,const char* family,int faceIndex) {
    if(faceIndex<0) return Skia_ParagraphFail("Font face index must be nonnegative");
    if(fonts->sealed) return Skia_ParagraphFail("Add fonts before creating any builder from the collection");
    if(!family || !*family) return Skia_ParagraphFail("Font family alias must not be empty");
    auto manager=SkFontMgr_New_Custom_Empty();
    auto face=manager?manager->makeFromFile(path,faceIndex):nullptr;
    if(!face) return Skia_ParagraphFail("Cannot load font file (missing, unreadable or unsupported)");
    fonts->provider->registerTypeface(std::move(face),SkString(family));
    fonts->collection->clearCaches();
    return true;
}
inline bool Skia_ParagraphAddFont(SkiaParagraphFonts* fonts,const char* path,const char* family) {
    return Skia_ParagraphAddFontFace(fonts,path,family,0);
}
inline SkiaParagraphTextStyle* Skia_NewParagraphTextStyle(float size,uint32_t color,int weight,int width,bool italic,
        float letterSpacing,float wordSpacing,float height,uint32_t decorations) {
    if(!std::isfinite(size) || size<=0 || size>4096 || weight<1 || weight>1000 || width<1 || width>9 ||
       !std::isfinite(letterSpacing) || !std::isfinite(wordSpacing) || !std::isfinite(height) || height<0 || (decorations&~7u)) {
        Skia_ParagraphFail("Invalid text style: size (0,4096], weight 1..1000, width 1..9, finite spacing, height >=0, decorations 0..7"); return nullptr;
    }
    auto style=std::make_unique<SkiaParagraphTextStyle>();
    style->setFontSize(size); style->setColor(color);
    style->setFontStyle(SkFontStyle(weight,width,italic?SkFontStyle::kItalic_Slant:SkFontStyle::kUpright_Slant));
    style->setLetterSpacing(letterSpacing); style->setWordSpacing(wordSpacing);
    style->setHeight(height); style->setHeightOverride(height>0);
    style->setDecoration(static_cast<skia_paragraph::TextDecoration>(decorations));
    style->setDecorationColor(color);
    // Never inherit Skia's platform-specific default font family.
    style->setFontFamilies({});
    return style.release();
}
inline void Skia_DeleteParagraphTextStyle(SkiaParagraphTextStyle* style) { delete style; }
inline bool Skia_ParagraphStyleFamilies(SkiaParagraphTextStyle* style,const das::TArray<char*>& families,const char* locale) {
    if(!families.size || families.size>64) return Skia_ParagraphFail("Provide 1..64 explicit font family aliases");
    auto names=reinterpret_cast<char* const*>(families.data);
    std::vector<SkString> copied; copied.reserve(size_t(families.size));
    for(uint64_t i=0;i<families.size;++i) {
        if(!names[i] || !*names[i]) return Skia_ParagraphFail("Font family aliases must not be empty");
        copied.emplace_back(names[i]);
    }
    style->setFontFamilies(std::move(copied)); style->setLocale(SkString(locale?locale:"und"));
    return true;
}
inline SkiaParagraphBuilder* Skia_NewParagraphBuilderImpl(SkiaParagraphFonts* fonts,const SkiaParagraphTextStyle* style,
        SkiaParagraphAlign align,SkiaParagraphDirection direction,int maxLines,const char* ellipsis,const SkiaParagraphStrut* strut,SkiaTextHeightBehavior heightBehavior=SkiaTextHeightBehavior::kAll) {
    if(int(heightBehavior)<0 || int(heightBehavior)>3) { Skia_ParagraphFail("Invalid text height behavior"); return nullptr; }
    if(maxLines<0 || int(align)<0 || int(align)>5 || int(direction)<0 || int(direction)>1) {
        Skia_ParagraphFail("Invalid paragraph alignment, direction or negative max_lines"); return nullptr;
    }
    if(style->getFontFamilies().empty() || !fonts->provider->countFamilies()) {
        Skia_ParagraphFail("Register a font and configure explicit style families before creating a builder"); return nullptr;
    }
    size_t bytes=ellipsis?std::strlen(ellipsis):0;
    if(bytes>4096 || (bytes && SkUTF::CountUTF8(ellipsis,bytes)<0)) {
        Skia_ParagraphFail("Ellipsis must be valid UTF-8 and at most 4096 bytes"); return nullptr;
    }
    auto unicode=SkUnicodes::ICU::Make();
    if(!unicode) { Skia_ParagraphFail("Cannot initialize ICU (check icudtl.dat on Windows)"); return nullptr; }
    skia_paragraph::ParagraphStyle settings;
    if(strut) settings.setStrutStyle(*strut);
    settings.setTextHeightBehavior(heightBehavior);
    settings.setTextStyle(*style); settings.setTextAlign(align); settings.setTextDirection(direction);
    settings.setMaxLines(maxLines?size_t(maxLines):std::numeric_limits<size_t>::max());
    settings.setEllipsis(SkString(ellipsis?ellipsis:""));
    settings.turnHintingOff(); settings.setApplyRoundingHack(false);
    auto builder=std::make_unique<SkiaParagraphBuilder>();
    builder->value=skia_paragraph::ParagraphBuilder::make(settings,fonts->collection,std::move(unicode));
    if(!builder->value) { Skia_ParagraphFail("Cannot create paragraph builder"); return nullptr; }
    fonts->sealed=true;
    return builder.release();
}
inline SkiaParagraphBuilder* Skia_NewParagraphBuilder(SkiaParagraphFonts* fonts,const SkiaParagraphTextStyle* style,
        SkiaParagraphAlign align,SkiaParagraphDirection direction,int maxLines,const char* ellipsis) {
    return Skia_NewParagraphBuilderImpl(fonts,style,align,direction,maxLines,ellipsis,nullptr);
}
inline SkiaParagraphBuilder* Skia_NewParagraphBuilderWithStrut(SkiaParagraphFonts* fonts,const SkiaParagraphTextStyle* style,
        const SkiaParagraphStrut* strut,SkiaParagraphAlign align,SkiaParagraphDirection direction,int maxLines,const char* ellipsis) {
    return Skia_NewParagraphBuilderImpl(fonts,style,align,direction,maxLines,ellipsis,strut);
}
inline SkiaParagraphStrut* Skia_NewParagraphStrut(const SkiaParagraphTextStyle* fontStyle,bool enabled,float height,
        float leading,bool forceHeight,bool heightOverride,bool halfLeading) {
    if(fontStyle->getFontFamilies().empty() || !std::isfinite(height) || height<=0 || !std::isfinite(leading)) {
        Skia_ParagraphFail("Strut needs explicit font families, finite positive height and finite leading"); return nullptr;
    }
    auto strut=std::make_unique<SkiaParagraphStrut>();
    strut->setFontFamilies(fontStyle->getFontFamilies()); strut->setFontStyle(fontStyle->getFontStyle());
    strut->setFontSize(fontStyle->getFontSize()); strut->setStrutEnabled(enabled);
    strut->setHeight(height); strut->setLeading(leading); strut->setForceStrutHeight(forceHeight);
    strut->setHeightOverride(heightOverride); strut->setHalfLeading(halfLeading);
    return strut.release();
}
inline void Skia_DeleteParagraphStrut(SkiaParagraphStrut* strut) { delete strut; }
inline bool Skia_ParagraphAddPlaceholder(SkiaParagraphBuilder* builder,float width,float height,
        SkiaPlaceholderAlignment alignment,SkiaTextBaseline baseline,float offset,int& byte,int& units) {
    if(!builder->value) return Skia_ParagraphFail("Builder has already been consumed by build_paragraph");
    if(!std::isfinite(width) || width<0 || !std::isfinite(height) || height<0 || !std::isfinite(offset) ||
        int(alignment)<0 || int(alignment)>5 || int(baseline)<0 || int(baseline)>1)
        return Skia_ParagraphFail("Placeholder dimensions must be finite and nonnegative, offset finite, alignment/baseline valid");
    if(builder->bytes>1024*1024-3) return Skia_ParagraphFail("Placeholder would exceed paragraph's 1 MiB UTF-8 limit");
    byte=int(builder->bytes); units=builder->utf16Units;
    builder->value->addPlaceholder(skia_paragraph::PlaceholderStyle(width,height,alignment,baseline,offset));
    builder->text.append("\xEF\xBF\xBC",3); builder->bytes+=3; ++builder->utf16Units;
    return true;
}
inline void Skia_DeleteParagraphBuilder(SkiaParagraphBuilder* builder) { delete builder; }
inline bool Skia_ParagraphPushStyle(SkiaParagraphBuilder* builder,const SkiaParagraphTextStyle* style) {
    if(!builder->value) return Skia_ParagraphFail("Builder has already been consumed by build_paragraph");
    if(style->getFontFamilies().empty()) return Skia_ParagraphFail("Configure explicit style families before pushing");
    if(builder->depth>=256) return Skia_ParagraphFail("Paragraph style nesting limit is 256");
    builder->value->pushStyle(*style); ++builder->depth; return true;
}
inline bool Skia_ParagraphPopStyle(SkiaParagraphBuilder* builder) {
    if(!builder->value) return Skia_ParagraphFail("Builder has already been consumed by build_paragraph");
    if(!builder->depth) return Skia_ParagraphFail("Paragraph style stack is empty");
    builder->value->pop(); --builder->depth; return true;
}
inline bool Skia_ParagraphAddText(SkiaParagraphBuilder* builder,const char* text,uint32_t bytes) {
    if(!builder->value) return Skia_ParagraphFail("Builder has already been consumed by build_paragraph");
    if(bytes>1024*1024 || builder->bytes+bytes>1024*1024 || SkUTF::CountUTF8(text,bytes)<0 || (bytes && std::memchr(text,0,bytes)))
        return Skia_ParagraphFail("Paragraph text must be valid UTF-8 without embedded NUL, at most 1 MiB total");
    builder->value->addText(text,size_t(bytes)); builder->bytes+=bytes; builder->text.append(text,bytes);
    builder->utf16Units+=SkUTF::UTF8ToUTF16(nullptr,0,text,bytes); return true;
}
inline SkiaParagraph* Skia_BuildParagraph(SkiaParagraphBuilder* builder) {
    if(!builder->value || builder->depth) { Skia_ParagraphFail("Build requires an unused builder with balanced style push/pop"); return nullptr; }
    auto unicode=SkUnicodes::ICU::Make();
    auto breaks=unicode?unicode->makeBreakIterator(SkUnicode::BreakType::kGraphemes):nullptr;
    if(!breaks || !breaks->setText(builder->text.data(),int(builder->text.size()))) {
        Skia_ParagraphFail("Cannot initialize ICU grapheme boundaries"); return nullptr;
    }
    auto paragraph=std::make_unique<SkiaParagraph>();
    paragraph->value=builder->value->Build();
    if(!paragraph->value) { Skia_ParagraphFail("Cannot build paragraph"); return nullptr; }
    const auto& text=builder->text;
    paragraph->utf8To16.assign(text.size()+1,-1);
    const char* cursor=text.data(); const char* end=cursor+text.size();
    int32_t units=0;
    while(cursor<end) {
        auto byte=int32_t(cursor-text.data());
        paragraph->utf8To16[size_t(byte)]=units;
        auto scalar=SkUTF::NextUTF8(&cursor,end); // validated by AddText
        paragraph->utf16To8.push_back(byte);
        ++units;
        if(scalar>0xffff) { paragraph->utf16To8.push_back(-1); ++units; }
    }
    paragraph->utf8To16[text.size()]=units;
    paragraph->utf16To8.push_back(int32_t(text.size()));
    for(auto at=breaks->first(); !breaks->isDone(); at=breaks->next()) {
        if(at>=0 && size_t(at)<paragraph->utf8To16.size())
            paragraph->graphemes.push_back(paragraph->utf8To16[size_t(at)]);
    }
    // ICU includes both endpoints, including the single boundary of empty text.
    if(paragraph->graphemes.empty()) paragraph->graphemes.push_back(0);
    breaks.reset();
    builder->value.reset(); builder->text.clear();
    return paragraph.release();
}
inline void Skia_DeleteParagraph(SkiaParagraph* paragraph) { delete paragraph; }
inline bool Skia_LayoutParagraph(SkiaParagraph* paragraph,float width) {
    if(!std::isfinite(width) || width<=0) return Skia_ParagraphFail("Layout width must be finite and positive");
    paragraph->value->layout(width);
    paragraph->lines.clear(); paragraph->value->getLineMetrics(paragraph->lines); paragraph->laidOut=true;
    return true;
}
inline bool Skia_ParagraphMetrics(SkiaParagraph* paragraph,float& width,float& height,float& minIntrinsic,float& maxIntrinsic,
        float& alphabetic,float& ideographic,float& longest,int& lines,int& unresolved,bool& exceeded) {
    if(!paragraph->laidOut) return Skia_ParagraphFail("Call layout_paragraph before reading metrics");
    auto& p=*paragraph->value;
    width=p.getMaxWidth(); height=p.getHeight(); minIntrinsic=p.getMinIntrinsicWidth(); maxIntrinsic=p.getMaxIntrinsicWidth();
    alphabetic=p.getAlphabeticBaseline(); ideographic=p.getIdeographicBaseline(); longest=p.getLongestLine();
    lines=int(paragraph->lines.size()); unresolved=p.unresolvedGlyphs(); exceeded=p.didExceedMaxLines(); return true;
}
inline bool Skia_ParagraphLineMetrics(SkiaParagraph* paragraph,int index,float& ascent,float& descent,float& height,
        float& width,float& left,float& baseline,bool& hardBreak) {
    if(!paragraph->laidOut || index<0 || size_t(index)>=paragraph->lines.size()) return Skia_ParagraphFail("Line index outside laid-out paragraph");
    const auto& m=paragraph->lines[size_t(index)];
    ascent=float(m.fAscent); descent=float(m.fDescent); height=float(m.fHeight); width=float(m.fWidth);
    left=float(m.fLeft); baseline=float(m.fBaseline); hardBreak=m.fHardBreak; return true;
}
// Like native Paragraph::paint this returns void. Call layout first; the script
// caller observes that precondition; painting has no synthetic success result.
inline void Skia_DrawParagraph(SkCanvas* canvas,SkiaParagraph* paragraph,float x,float y) {
    paragraph->value->paint(canvas,x,y);
}

inline void Skia_ParagraphTextLength(const SkiaParagraph* paragraph,int& utf8,int& utf16) {
    utf8=int(paragraph->utf8To16.size()-1); utf16=int(paragraph->utf16To8.size()-1);
}
inline bool Skia_ParagraphUtf8ToUtf16(const SkiaParagraph* paragraph,int byte,int& units) {
    if(byte<0 || size_t(byte)>=paragraph->utf8To16.size() || paragraph->utf8To16[size_t(byte)]<0)
        return Skia_ParagraphFail("UTF-8 index must be a Unicode scalar boundary in [0,text_bytes]");
    units=paragraph->utf8To16[size_t(byte)]; return true;
}
inline bool Skia_ParagraphUtf16ToUtf8(const SkiaParagraph* paragraph,int units,int& byte) {
    if(units<0 || size_t(units)>=paragraph->utf16To8.size() || paragraph->utf16To8[size_t(units)]<0)
        return Skia_ParagraphFail("UTF-16 index must be a Unicode scalar boundary in [0,text_utf16_units]");
    byte=paragraph->utf16To8[size_t(units)]; return true;
}
inline bool Skia_ParagraphHitTest(SkiaParagraph* paragraph,float x,float y,int& utf16,int& utf8,SkiaParagraphAffinity& affinity) {
    if(!paragraph->laidOut) return Skia_ParagraphFail("Call layout_paragraph before hit testing");
    if(!std::isfinite(x) || !std::isfinite(y)) return Skia_ParagraphFail("Hit-test coordinates must be finite");
    auto hit=paragraph->value->getGlyphPositionAtCoordinate(x,y);
    utf16=hit.position; affinity=hit.affinity;
    return Skia_ParagraphUtf16ToUtf8(paragraph,utf16,utf8);
}
inline bool Skia_ParagraphWordBoundaryUtf16(SkiaParagraph* paragraph,int position,int& start,int& end) {
    if(!paragraph->laidOut) return Skia_ParagraphFail("Call layout_paragraph before word boundaries");
    int byte;
    if(!Skia_ParagraphUtf16ToUtf8(paragraph,position,byte)) return false;
    auto range=paragraph->value->getWordBoundary(unsigned(position));
    start=int(range.start); end=int(range.end); return true;
}
// A temporary snapshot for copying the public TextBox vector to language values.
// It owns only geometry, remains valid after relayout or paragraph destruction.
struct SkiaParagraphRects { std::vector<skia_paragraph::TextBox> values; };
inline SkiaParagraphRects* Skia_ParagraphRangeRectsUtf16(SkiaParagraph* paragraph,int start,int end,
        SkiaParagraphRectHeight height,SkiaParagraphRectWidth width) {
    if(!paragraph->laidOut) { Skia_ParagraphFail("Call layout_paragraph before range rectangles"); return nullptr; }
    int byte;
    if(!Skia_ParagraphUtf16ToUtf8(paragraph,start,byte) || !Skia_ParagraphUtf16ToUtf8(paragraph,end,byte)) return nullptr;
    if(start>end || int(height)<0 || int(height)>5 || int(width)<0 || int(width)>1) {
        Skia_ParagraphFail("Invalid range order or rectangle style"); return nullptr;
    }
    auto result=std::make_unique<SkiaParagraphRects>();
    result->values=paragraph->value->getRectsForRange(unsigned(start),unsigned(end),height,width);
    return result.release();
}
inline void Skia_DeleteParagraphRects(SkiaParagraphRects* rects) { delete rects; }
inline int Skia_ParagraphRectCount(const SkiaParagraphRects* rects) { return int(rects->values.size()); }
inline bool Skia_ParagraphRectAt(const SkiaParagraphRects* rects,int index,float& x,float& y,float& w,float& h,SkiaParagraphDirection& direction) {
    if(index<0 || size_t(index)>=rects->values.size()) return Skia_ParagraphFail("Rectangle index outside snapshot");
    const auto& box=rects->values[size_t(index)];
    x=box.rect.x(); y=box.rect.y(); w=box.rect.width(); h=box.rect.height(); direction=box.direction; return true;
}

inline bool Skia_ParagraphGraphemeBoundaryUtf16(const SkiaParagraph* p,int position,bool& boundary,int& previous,int& next) {
    int byte;
    if(!Skia_ParagraphUtf16ToUtf8(p,position,byte)) return false;
    const auto& g=p->graphemes;
    auto lower=std::lower_bound(g.begin(),g.end(),position);
    auto upper=std::upper_bound(g.begin(),g.end(),position);
    boundary=lower!=g.end() && *lower==position;
    previous=lower==g.begin()?g.front():*std::prev(lower);
    next=upper==g.end()?g.back():*upper;
    return true;
}
inline bool Skia_ParagraphGraphemeInfoUtf16(SkiaParagraph* p,int position,bool& found,
        int& start,int& end,float& x,float& y,float& w,float& h,SkiaParagraphDirection& direction,bool& ellipsis) {
    found=false;
    if(!p->laidOut) return Skia_ParagraphFail("Call layout_paragraph before grapheme geometry");
    int byte;
    if(!Skia_ParagraphUtf16ToUtf8(p,position,byte)) return false;
    if(size_t(position)+1==p->utf16To8.size()) return true;
    // In m138 the native method can return true without filling GlyphInfo for
    // newline/zero geometry. Initialize and require an actual nonempty range.
    skia_paragraph::Paragraph::GlyphInfo info{};
    if(!p->value->getGlyphInfoAtUTF16Offset(size_t(position),&info) || info.fGraphemeClusterTextRange.empty()) return true;
    start=int(info.fGraphemeClusterTextRange.start); end=int(info.fGraphemeClusterTextRange.end);
    x=info.fGraphemeLayoutBounds.x(); y=info.fGraphemeLayoutBounds.y();
    w=info.fGraphemeLayoutBounds.width(); h=info.fGraphemeLayoutBounds.height();
    direction=info.fDirection; ellipsis=info.fIsEllipsis; found=true; return true;
}
inline bool Skia_ParagraphCaretUtf16(SkiaParagraph* p,int position,SkiaParagraphAffinity affinity,
        bool& found,float& x,float& y,float& h,SkiaParagraphDirection& direction) {
    found=false;
    if(!p->laidOut) return Skia_ParagraphFail("Call layout_paragraph before caret geometry");
    if(affinity!=SkiaParagraphAffinity::kUpstream && affinity!=SkiaParagraphAffinity::kDownstream)
        return Skia_ParagraphFail("Invalid caret affinity");
    bool boundary; int previous,next;
    if(!Skia_ParagraphGraphemeBoundaryUtf16(p,position,boundary,previous,next)) return false;
    if(!boundary) return Skia_ParagraphFail("Caret position must be an ICU grapheme boundary");
    bool upstream=affinity==SkiaParagraphAffinity::kUpstream;
    if((upstream && position==0) || (!upstream && size_t(position)+1==p->utf16To8.size())) return true;
    int start,end; float w; bool ellipsis;
    if(!Skia_ParagraphGraphemeInfoUtf16(p,upstream?previous:position,found,start,end,x,y,w,h,direction,ellipsis)) return false;
    // Ellipsis geometry is synthetic; do not assign it an insertion caret.
    if(!found || ellipsis || w<=0 || h<=0) { found=false; return true; }
    if(upstream ? direction==SkiaParagraphDirection::kLtr : direction==SkiaParagraphDirection::kRtl) x+=w;
    return true;
}

inline SkiaParagraphRects* Skia_ParagraphPlaceholderRects(SkiaParagraph* paragraph) {
    if(!paragraph->laidOut) { Skia_ParagraphFail("Call layout_paragraph before placeholder rectangles"); return nullptr; }
    auto result=std::make_unique<SkiaParagraphRects>();
    result->values=paragraph->value->getRectsForPlaceholders();
    return result.release();
}

inline void Skia_SetParagraphForeground(SkiaParagraphTextStyle* style,const SkPaint* paint) {
    if(paint) style->setForegroundPaint(*paint); else style->clearForegroundColor();
}
inline void Skia_SetParagraphBackground(SkiaParagraphTextStyle* style,const SkPaint* paint) {
    if(paint) style->setBackgroundPaint(*paint); else style->clearBackgroundColor();
}
inline bool Skia_ParagraphAddFontFeature(SkiaParagraphTextStyle* style,const char* tag,uint32_t bytes,int value) {
    if(!tag || bytes!=4 || value<0)
        return Skia_ParagraphFail("Font feature requires a 4-byte printable ASCII tag and nonnegative int value");
    for(int i=0;i<4;++i) if(uint8_t(tag[i])<0x20 || uint8_t(tag[i])>0x7e)
        return Skia_ParagraphFail("Font feature tag must contain exactly four printable ASCII bytes");
    if(style->getFontFeatureNumber()>=256) return Skia_ParagraphFail("Text style font-feature limit is 256 entries");
    style->addFontFeature(SkString(tag,4),value); return true;
}
inline void Skia_ParagraphResetFontFeatures(SkiaParagraphTextStyle* style) { style->resetFontFeatures(); }

inline SkiaParagraphBuilder* Skia_NewParagraphBuilderLayout(SkiaParagraphFonts* fonts,const SkiaParagraphTextStyle* style,
        const SkiaParagraphStrut* strut,SkiaParagraphAlign align,SkiaParagraphDirection direction,int maxLines,const char* ellipsis,SkiaTextHeightBehavior behavior) {
    return Skia_NewParagraphBuilderImpl(fonts,style,align,direction,maxLines,ellipsis,strut,behavior);
}
inline bool Skia_FontTag(const char* text,uint32_t bytes,uint32_t& tag) {
    if(!text || bytes!=4) return Skia_ParagraphFail("Font tag must contain four printable ASCII bytes");
    tag=0;
    for(unsigned i=0;i<4;++i) {
        auto c=uint8_t(text[i]); if(c<0x20 || c>0x7e) return Skia_ParagraphFail("Font tag must contain four printable ASCII bytes");
        tag=(tag<<8)|c;
    }
    return true;
}
inline char* Skia_FontTagName(uint32_t tag,das::Context* context,das::LineInfoArg* at) {
    char name[4]={char(tag>>24),char(tag>>16),char(tag>>8),char(tag)};
    return context->allocateString(name,4,at);
}
inline bool Skia_FontAxisCount(const SkFont* font,int& count) {
    count=font->getTypeface()->getVariationDesignParameters(nullptr,0);
    if(count<0 || count>1024) return Skia_ParagraphFail("Cannot enumerate font variation axes (limit 1024)");
    return true;
}
inline bool Skia_FontAxis(const SkFont* font,int index,uint32_t& tag,float& minimum,float& normal,float& maximum,bool& hidden) {
    int count;
    if(!Skia_FontAxisCount(font,count)) return false;
    if(index<0 || index>=count) return Skia_ParagraphFail("Font variation axis index outside font");
    std::vector<SkFontParameters::Variation::Axis> axes; axes.resize(size_t(count));
    if(font->getTypeface()->getVariationDesignParameters(axes.data(),count)!=count) return Skia_ParagraphFail("Cannot read font variation axes");
    const auto& axis=axes[size_t(index)];tag=axis.tag;minimum=axis.min;normal=axis.def;maximum=axis.max;hidden=axis.isHidden();return true;
}
inline bool Skia_ParagraphFontArguments(SkiaParagraphTextStyle* style,int faceIndex,const das::TArray<uint32_t>& tags,const das::TArray<float>& values) {
    if(faceIndex<0 || tags.size!=values.size || tags.size>64) return Skia_ParagraphFail("Font arguments require nonnegative face index and matching axis arrays (limit 64)");
    auto rawTags=reinterpret_cast<const uint32_t*>(tags.data);auto rawValues=reinterpret_cast<const float*>(values.data);
    std::vector<SkFontArguments::VariationPosition::Coordinate> coordinates;
    for(uint64_t i=0;i<tags.size;++i) {
        for(int shift=24;shift>=0;shift-=8) { auto c=(rawTags[i]>>shift)&255; if(c<0x20 || c>0x7e) return Skia_ParagraphFail("Variation tags must be printable ASCII"); }
        if(!std::isfinite(rawValues[i])) return Skia_ParagraphFail("Variation coordinates must be finite");
        for(uint64_t j=0;j<i;++j) if(rawTags[j]==rawTags[i]) return Skia_ParagraphFail("Duplicate variation axis");
        coordinates.push_back({rawTags[i],rawValues[i]});
    }
    SkFontArguments args;SkFontArguments::VariationPosition::Coordinate empty{};SkFontArguments::Palette::Override emptyPalette{};
    args.setCollectionIndex(faceIndex).setVariationDesignPosition({coordinates.empty()?&empty:coordinates.data(),int(coordinates.size())});
    args.setPalette({0,&emptyPalette,0});
    style->setFontArguments(args); // native TextStyle makes owning copies
    return true;
}
inline void Skia_ParagraphClearFontArguments(SkiaParagraphTextStyle* style) { style->setFontArguments(std::nullopt); }
inline bool Skia_ParagraphDecoration(SkiaParagraphTextStyle* style,uint32_t bits,uint32_t color,SkiaTextDecorationStyle kind,SkiaTextDecorationMode mode,float thickness) {
    if((bits&~7u) || int(kind)<0 || int(kind)>4 || int(mode)<0 || int(mode)>1 || !std::isfinite(thickness) || thickness<0)
        return Skia_ParagraphFail("Invalid decoration bits/style/mode or thickness");
    style->setDecoration(static_cast<skia_paragraph::TextDecoration>(bits));style->setDecorationColor(color);
    style->setDecorationStyle(kind);style->setDecorationMode(mode);style->setDecorationThicknessMultiplier(thickness);return true;
}
inline bool Skia_ParagraphAddShadow(SkiaParagraphTextStyle* style,uint32_t color,float x,float y,float sigma) {
    if(!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(sigma) || sigma<0 || style->getShadowNumber()>=256)
        return Skia_ParagraphFail("Shadow offset/sigma must be finite, sigma nonnegative, at most 256 shadows");
    style->addShadow(skia_paragraph::TextShadow(color,SkPoint::Make(x,y),sigma));return true;
}
inline void Skia_ParagraphResetShadows(SkiaParagraphTextStyle* style) { style->resetShadows(); }
inline bool Skia_ParagraphBaselineShift(SkiaParagraphTextStyle* style,float shift) {
    if(!std::isfinite(shift)) return Skia_ParagraphFail("Baseline shift must be finite");
    style->setBaselineShift(shift);return true;
}
