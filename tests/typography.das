options gen2
require dasskia/skia_paragraph
require dasskia/skia_text
require dasskia/skia_scope
require math

def check_typography(value : bool; message : string) : SkiaStatus {
    if (!value) { return err(skia_error("typography_test",message),type<SkiaUnit>) }
    return skia_ok()
}
def typography_text(fonts : SkiaParagraphFonts?; style : SkiaParagraphTextStyle?; text : string; settings : ParagraphOptions = ParagraphOptions()) {
    return fonts |> with_paragraph_builder(style,settings) $(builder : SkiaParagraphBuilder?) {
        builder |> add_paragraph_text(text) |> skia_try
        return <- build_paragraph(builder)
    }
}
def test_typography() : SkiaStatus {
    return skia_scope() {
        let font : SkFont? = with_font_file("assets/fonts/Distortable.ttf",FontOptions(size=64.0)) |> skia_use
        var info <- font |> font_variation_axes() |> skia_try
        check_typography(length(info)==1 && info[0].tag=="wght" && info[0].minimum==0.5 && info[0].normal==1.0 && info[0].maximum==2.0,"pinned variable font metadata") |> skia_try
        let static_font : SkFont? = with_font_file("assets/fonts/DejaVuSans.ttf",FontOptions()) |> skia_use
        var static_axes <- static_font |> font_variation_axes() |> skia_try
        check_typography(length(static_axes)==0,"static font axes") |> skia_try
        let fonts : SkiaParagraphFonts? = with_paragraph_fonts() |> skia_use
        fonts |> add_paragraph_font("assets/fonts/Distortable.ttf","Variable") |> skia_try
        fonts |> add_paragraph_font("assets/fonts/DejaVuSans.ttf","Demo") |> skia_try
        check_typography(is_err(add_paragraph_font(fonts,"assets/fonts/ExampleCollection.ttc","Bad",-1)) &&
            is_err(add_paragraph_font(fonts,"assets/fonts/ExampleCollection.ttc","Bad",2)),"invalid TTC indices") |> skia_try
        fonts |> add_paragraph_font("assets/fonts/ExampleCollection.ttc","Face0",0) |> skia_try
        fonts |> add_paragraph_font("assets/fonts/ExampleCollection.ttc","Face1",1) |> skia_try
        var family <- array("Variable")
        var demo <- array("Demo")
        let variable : SkiaParagraphTextStyle? = with_paragraph_style(family,ParagraphTextOptions(size=84.0,color=0xffffffffu)) |> skia_use
        let body : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=48.0,color=0xffffffffu)) |> skia_use
        var axes <- array(FontVariation(tag="wght",value=0.5))
        variable |> set_paragraph_font_arguments(axes) |> skia_try
        let light : SkiaParagraph? = typography_text(fonts,variable,"abcabc") |> with_paragraph() |> skia_use
        axes[0].value=2.0
        variable |> set_paragraph_font_arguments(axes) |> skia_try
        let heavy : SkiaParagraph? = typography_text(fonts,variable,"abcabc") |> with_paragraph() |> skia_use
        clear(axes)
        variable |> clear_paragraph_font_arguments()
        let restored : SkiaParagraph? = typography_text(fonts,variable,"abcabc") |> with_paragraph() |> skia_use
        push(axes,FontVariation(tag="wgh",value=1.0))
        check_typography(is_err(set_paragraph_font_arguments(variable,axes)),"invalid axis tag") |> skia_try
        axes[0]=FontVariation(tag="wght",value=sqrt(-1.0))
        check_typography(is_err(set_paragraph_font_arguments(variable,axes)),"nonfinite axis") |> skia_try
        axes[0]=FontVariation(tag="wght",value=1.0);push(axes,axes[0])
        check_typography(is_err(set_paragraph_font_arguments(variable,axes)),"duplicate axis") |> skia_try
        clear(axes);push(axes,FontVariation(tag="opsz",value=14.0))
        variable |> set_paragraph_font_arguments(axes) |> skia_try
        let ignored : SkiaParagraph? = typography_text(fonts,variable,"abcabc") |> with_paragraph() |> skia_use
        light |> layout_paragraph(600.0) |> skia_try
        heavy |> layout_paragraph(600.0) |> skia_try
        restored |> layout_paragraph(600.0) |> skia_try
        ignored |> layout_paragraph(600.0) |> skia_try
        let surface : SkSurface? = with_raster_surface(RasterSurfaceOptions(size=int2(650,650))) |> skia_use
        let c=canvas(surface)
        c |> clear(0xff000000u)
        c |> draw_paragraph(light,float2(10.0,10.0))
        c |> draw_paragraph(heavy,float2(10.0,140.0))
        c |> draw_paragraph(restored,float2(10.0,270.0))
        c |> draw_paragraph(ignored,float2(10.0,400.0))
        var changed,reset_changed,unknown_changed : int
        for (y in 0 .. 120) {
            for (x in 0 .. 600) {
                let a=surface |> read_pixel(int2(x,y)) |> skia_try
                let b=surface |> read_pixel(int2(x,y+130)) |> skia_try
                let d=surface |> read_pixel(int2(x,y+260)) |> skia_try
                let e=surface |> read_pixel(int2(x,y+390)) |> skia_try
                if (a!=b) { changed++ }
                if (a!=d) { reset_changed++ }
                if (d!=e) { unknown_changed++ }
            }
        }
        check_typography(changed>500 && reset_changed>100 && unknown_changed==0,"real variable outlines, copied coordinates, reset and unsupported-axis native behavior") |> skia_try
        var f0 <- array("Face0"); var f1 <- array("Face1")
        let face0 : SkiaParagraphTextStyle? = with_paragraph_style(f0,ParagraphTextOptions(size=40.0)) |> skia_use
        let face1 : SkiaParagraphTextStyle? = with_paragraph_style(f1,ParagraphTextOptions(size=40.0)) |> skia_use
        let p0 : SkiaParagraph? = typography_text(fonts,face0,"abc") |> with_paragraph() |> skia_use
        let p1 : SkiaParagraph? = typography_text(fonts,face1,"AV Привет") |> with_paragraph() |> skia_use
        p0 |> layout_paragraph(500.0) |> skia_try;p1 |> layout_paragraph(500.0) |> skia_try
        let m0=paragraph_metrics(p0) |> skia_try;let m1=paragraph_metrics(p1) |> skia_try
        check_typography(m0.unresolved_glyphs==0 && m1.unresolved_glyphs==0,"TTC face selection at registration") |> skia_try
        check_typography(is_err(set_paragraph_decoration(body,ParagraphDecorationOptions(bits=8u))) &&
            is_err(set_paragraph_decoration(body,ParagraphDecorationOptions(thickness=-1.0))) &&
            is_err(add_paragraph_shadow(body,ParagraphShadowOptions(blur_sigma=-1.0))) &&
            is_err(set_paragraph_baseline_shift(body,sqrt(-1.0))),"invalid typography parameters") |> skia_try
        body |> set_paragraph_decoration(ParagraphDecorationOptions(bits=7u,color=0xff39b5f0u,style=SkiaTextDecorationStyle.Wavy,thickness=2.0)) |> skia_try
        body |> add_paragraph_shadow(ParagraphShadowOptions(color=0xffff0000u,offset=float2(10.0,5.0))) |> skia_try
        body |> add_paragraph_shadow(ParagraphShadowOptions(color=0xff00ff00u,offset=float2(-8.0,8.0),blur_sigma=1.0)) |> skia_try
        let decorated : SkiaParagraph? = typography_text(fonts,body,"Decorated") |> with_paragraph() |> skia_use
        body |> reset_paragraph_shadows()
        body |> set_paragraph_decoration(ParagraphDecorationOptions()) |> skia_try
        let plain : SkiaParagraph? = typography_text(fonts,body,"Decorated") |> with_paragraph() |> skia_use
        decorated |> layout_paragraph(600.0) |> skia_try;plain |> layout_paragraph(600.0) |> skia_try
        c |> clear(0xff000000u)
        c |> draw_paragraph(decorated,float2(20.0,20.0));c |> draw_paragraph(plain,float2(20.0,140.0))
        var cyan,red,green,plain_color : int
        for (y in 10 .. 125) {
            for (x in 5 .. 500) {
                let p=surface |> read_pixel(int2(x,y)) |> skia_try
                let r=(p>>16)&255u;let g=(p>>8)&255u;let b=p&255u
                if (b>150u && g>100u && r<100u) { cyan++ }
                if (r>150u && g<80u && b<80u) { red++ }
                if (g>100u && r<80u && b<80u) { green++ }
                let q=surface |> read_pixel(int2(x,y+120)) |> skia_try
                if (q!=0xff000000u && ((q>>16)&255u)!=(q&255u)) { plain_color++ }
            }
        }
        check_typography(cyan>100 && red>100 && green>100 && plain_color==0,"decoration/shadow paint, multiple shadows, snapshot/reset") |> skia_try
        let up : SkiaParagraph? = with_paragraph_builder(fonts,body,ParagraphOptions()) $(b : SkiaParagraphBuilder?) {
            b |> add_paragraph_text("base ") |> skia_try
            body |> set_paragraph_baseline_shift(-12.0) |> skia_try
            b |> push_paragraph_style(body) |> skia_try
            b |> add_paragraph_text("shift") |> skia_try;b |> pop_paragraph_style() |> skia_try
            body |> set_paragraph_baseline_shift(0.0) |> skia_try
            return <- build_paragraph(b)
        } |> with_paragraph() |> skia_use
        up |> layout_paragraph(500.0) |> skia_try
        c |> clear(0xff000000u);c |> draw_paragraph(up,float2(20.0,20.0))
        var left_box <- up |> paragraph_rects_utf16(0,4) |> skia_try
        var right_box <- up |> paragraph_rects_utf16(5,10) |> skia_try
        var left_top=650;var right_top=650
        for (y in 0 .. 130) {
            for (x in int(left_box[0].rect.x)+20 .. int(left_box[0].rect.x+left_box[0].rect.z)+20) {
                let ink=surface |> read_pixel(int2(x,y)) |> skia_try
                if ((ink&255u)>100u) { left_top=min(left_top,y) }
            }
            for (x in int(right_box[0].rect.x)+20 .. int(right_box[0].rect.x+right_box[0].rect.z)+20) {
                let ink=surface |> read_pixel(int2(x,y)) |> skia_try
                if ((ink&255u)>100u) { right_top=min(right_top,y) }
            }
        }
        check_typography(right_top<left_top-8,"negative baseline shift raises text relative to base run") |> skia_try
        let tall : SkiaParagraphTextStyle? = with_paragraph_style(demo,ParagraphTextOptions(size=40.0,height=2.0)) |> skia_use
        let all : SkiaParagraph? = typography_text(fonts,tall,"first\nlast") |> with_paragraph() |> skia_use
        let trim : SkiaParagraph? = typography_text(fonts,tall,"first\nlast",ParagraphOptions(height_behavior=SkiaTextHeightBehavior.DisableAll)) |> with_paragraph() |> skia_use
        all |> layout_paragraph(500.0) |> skia_try;trim |> layout_paragraph(500.0) |> skia_try
        let am=paragraph_metrics(all) |> skia_try;let tm=paragraph_metrics(trim) |> skia_try
        check_typography(tm.height<am.height && tm.alphabetic_baseline<am.alphabetic_baseline,"first/last text-height behavior") |> skia_try
        var signature=2166136261u
        for (v in array(am.height,tm.height,tm.alphabetic_baseline,m0.longest_line,m1.longest_line)) {
            signature=(signature ^ uint(int(round(v*64.0))))*16777619u
        }
        print("TYPOGRAPHY_SIGNATURE={signature}\n")
        return skia_ok()
    }
}
[export]
def main() : int {
    let result=test_typography()
    if (is_err(result)) { let e=unwrap_err(result);print("FAIL {e.operation}: {e.message}\n");return 1 }
    print("PASS typography: variation axes, TTC, copied arguments, decorations, shadows, baseline, height behavior\n")
    return 0
}
