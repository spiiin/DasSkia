"""Browser rendering checks. Uses actual canvas pixels, not just compile success."""
import os
import argparse
import base64
import json
import shutil
import io
import re
import subprocess
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright
from web_browser import launch_browser,record_renderer

def serve_html(body):
    # Keep one callback argument: Playwright supplies Request as argument two.
    def handler(route):
        route.fulfill(status=200,content_type='text/html',body=body)
    return handler

p=argparse.ArgumentParser()
p.add_argument('--url',default='http://127.0.0.1:8080')
p.add_argument('--browser',choices=['chromium','firefox'],default='chromium')
p.add_argument('--strict-aot',action='store_true',help='Require strict web AOT markers, negative oracles and lifecycle shutdown checks')
p.add_argument('--sdl-interop',action='store_true',help='Test optional dasSDL3 integration build')
p.add_argument('--executable',help='Optional installed browser executable')
p.add_argument('--native-runner',help='Compare shaping signature against this native runner')
a=p.parse_args()
out=Path(__file__).resolve().parents[1]/'build/browser-tests'
out.mkdir(parents=True,exist_ok=True)
artifact_tag=a.browser+('-ci' if os.environ.get('DASSKIA_CI_SOFTWARE_RENDERING')=='1' else '')+('-aot' if a.strict_aot else '')
native_signature=None
native_paragraph_signature=None
native_selection_signature=None
native_caret_signature=None
native_inline_signature=None
native_text_style_signature=None
native_typography_signature=None
native_picture_bytes=None
native_graph_bytes=None
native_advanced_bytes=None
root=Path(__file__).resolve().parents[1]
if a.native_runner:
    runner=Path(a.native_runner).resolve()
    native=subprocess.run([str(runner),str(Path(__file__).resolve().parents[1]/'tests/text.das')],
                          cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_signature=re.search(r'SHAPING_SIGNATURE=(\S+)',native.stdout).group(1)
    paragraph_native=subprocess.run([str(runner),str(root/'tests/paragraph.das')],
                                    cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_paragraph_signature=re.search(r'PARAGRAPH_SIGNATURE=(\S+)',paragraph_native.stdout).group(1)
    selection_native=subprocess.run([str(runner),str(root/'tests/selection.das')],
                                    cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_selection_signature=re.search(r'SELECTION_SIGNATURE=(\S+)',selection_native.stdout).group(1)
    caret_native=subprocess.run([str(runner),str(root/'tests/caret.das')],
                                cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_caret_signature=re.search(r'CARET_SIGNATURE=(\S+)',caret_native.stdout).group(1)
    inline_native=subprocess.run([str(runner),str(root/'tests/inline_layout.das')],
                                 cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_inline_signature=re.search(r'INLINE_SIGNATURE=(\S+)',inline_native.stdout).group(1)
    text_style_native=subprocess.run([str(runner),str(root/'tests/text_style.das')],
                                     cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_text_style_signature=re.search(r'TEXT_STYLE_SIGNATURE=(\S+)',text_style_native.stdout).group(1)
    typography_native=subprocess.run([str(runner),str(root/'tests/typography.das')],
                                     cwd=runner.parent.parent,text=True,capture_output=True,check=True)
    native_typography_signature=re.search(r'TYPOGRAPHY_SIGNATURE=(\S+)',typography_native.stdout).group(1)
    fixture_dir=out/(artifact_tag+'-native-fixture')
    fixture_dir.mkdir(parents=True,exist_ok=True)
    shutil.copytree(root/'assets',fixture_dir/'assets',dirs_exist_ok=True)
    subprocess.run([str(runner),str(root/'tests/picture.das')],cwd=fixture_dir,
                   text=True,capture_output=True,check=True)
    native_picture_bytes=(fixture_dir/'picture-roundtrip.skp').read_bytes()
    subprocess.run([str(runner),str(root/'tests/filter_graph.das')],cwd=fixture_dir,
                   text=True,capture_output=True,check=True)
    native_graph_bytes=(fixture_dir/'filter-graph-roundtrip.skp').read_bytes()
    subprocess.run([str(runner),str(root/'tests/advanced_filters.das')],cwd=fixture_dir,
                   text=True,capture_output=True,check=True)
    native_advanced_bytes=(fixture_dir/'advanced-filters-roundtrip.skp').read_bytes()
with sync_playwright() as pw:
    browser=launch_browser(pw,a.browser,a.executable)
    try:
        page=browser.new_page(viewport={'width':1000,'height':850})
        errors=[]
        def require_aot():
            if not a.strict_aot: return
            log=page.locator('#log').inner_text()
            assert 'STRICT_AOT=1; fallback disabled' in log,log
            assert 'main AOT=yes; fallback disabled' in log or (
                'app_init AOT=yes; fallback disabled' in log and 'app_frame AOT=yes; fallback disabled' in log),log
        page.on('pageerror',lambda e: errors.append(str(e)))
        for script,expected in [('/tests/codecs.das','PASS codecs:'),('/tests/raster.das','PASS raster:'),('/tests/sdl_gl.das','PASS SDL GL:'),('/tests/text.das','PASS text:'),('/tests/paragraph.das','PASS paragraph:'),('/tests/selection.das','PASS selection:'),('/tests/caret.das','PASS caret:'),('/tests/inline_layout.das','PASS inline layout:'),('/tests/text_style.das','PASS text style:'),('/tests/typography.das','PASS typography:'),('/tests/drawing.das','PASS drawing:'),('/tests/effects.das','PASS effects:'),('/tests/geometry.das','PASS geometry:'),('/tests/picture.das','PASS picture:'),('/tests/runtime.das','PASS runtime:'),('/tests/filter_graph.das','PASS filter graph:'),('/tests/advanced_filters.das','PASS advanced filters:')]:
            page.goto(a.url+'/?script='+script,wait_until='domcontentloaded')
            page.wait_for_function('(s)=>{let t=document.querySelector("#log").textContent;return t.includes(s)||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',arg=expected,timeout=180000)
            assert expected in page.locator('#log').inner_text(),page.locator('#log').inner_text()
            assert not errors,errors; require_aot()
            if script=='/tests/typography.das':
                signature=re.search(r'TYPOGRAPHY_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_typography_signature:
                    assert signature==native_typography_signature,(signature,native_typography_signature)
                print(a.browser,'TYPOGRAPHY_SIGNATURE='+signature)
            if script=='/tests/text_style.das':
                signature=re.search(r'TEXT_STYLE_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_text_style_signature:
                    assert signature==native_text_style_signature,(signature,native_text_style_signature)
                print(a.browser,'TEXT_STYLE_SIGNATURE='+signature)
            if script=='/tests/inline_layout.das':
                signature=re.search(r'INLINE_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_inline_signature:
                    assert signature==native_inline_signature,(signature,native_inline_signature)
                print(a.browser,'INLINE_SIGNATURE='+signature)
            if script=='/tests/caret.das':
                signature=re.search(r'CARET_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_caret_signature:
                    assert signature==native_caret_signature,(signature,native_caret_signature)
                print(a.browser,'CARET_SIGNATURE='+signature)
            if script=='/tests/selection.das':
                signature=re.search(r'SELECTION_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_selection_signature:
                    assert signature==native_selection_signature,(signature,native_selection_signature)
                print(a.browser,'SELECTION_SIGNATURE='+signature)
            if script=='/tests/paragraph.das':
                signature=re.search(r'PARAGRAPH_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_paragraph_signature:
                    assert signature==native_paragraph_signature,(signature,native_paragraph_signature)
                print(a.browser,'PARAGRAPH_SIGNATURE='+signature)
            if script=='/tests/text.das':
                signature=re.search(r'SHAPING_SIGNATURE=(\S+)',page.locator('#log').inner_text()).group(1)
                if native_signature:
                    assert signature==native_signature,(signature,native_signature)
                print(a.browser,'SHAPING_SIGNATURE='+signature)
            if script in ('/tests/picture.das','/tests/filter_graph.das','/tests/advanced_filters.das') and native_picture_bytes:
                key={'/tests/picture.das':'picture','/tests/filter_graph.das':'filter-graph','/tests/advanced_filters.das':'advanced-filters'}[script]
                tag=key.replace('-',' ')
                encoded=page.evaluate("""(path)=>{let b=FS.readFile(path);let s='';
                    for(let i=0;i<b.length;i+=32768)s+=String.fromCharCode(...b.subarray(i,i+32768));return btoa(s)}""",key+'-roundtrip.skp')
                (fixture_dir/(key+'-interchange.skp')).write_bytes(base64.b64decode(encoded))
                interchange=str(root/('tests/'+key.replace('-','_')+'_interchange.das'))
                expected_interchange='PASS '+tag+' interchange:'
                native_check=subprocess.run([str(runner),interchange],cwd=fixture_dir,
                                            text=True,capture_output=True,check=True)
                assert expected_interchange in native_check.stdout,native_check.stdout
                strict=runner.with_name('dasSkia_aot_runner'+runner.suffix)
                if strict.exists():
                    aot_check=subprocess.run([str(strict),interchange],cwd=fixture_dir,
                                             text=True,capture_output=True,check=True)
                    assert 'AOT=yes' in aot_check.stdout and expected_interchange in aot_check.stdout,aot_check.stdout
                    print(a.browser,'WASM -> native '+tag+' interchange: interpreter + strict AOT PASS')
                else:
                    print(a.browser,'WASM -> native '+tag+' interchange PASS')
            if script=='/tests/codecs.das':
                for name,fmt,color,tolerance in [('codec-roundtrip.jpg','JPEG',(57,181,240,255),3),('codec-roundtrip-lossy.webp','WEBP',(57,181,240,255),5),('codec-roundtrip-alpha.webp','WEBP',(255,64,0,128),0),('codec-roundtrip-alpha-lossy.webp','WEBP',(255,64,0,128),5)]:
                    payload=bytes(page.evaluate('(name)=>Array.from(FS.readFile(name))',name))
                    decoded=Image.open(io.BytesIO(payload))
                    assert decoded.format==fmt and decoded.size==(64,48),(name,decoded.format,decoded.size)
                    actual=decoded.convert('RGBA').getpixel((20,20))
                    assert actual[3]==color[3],(name,actual,color)
                    assert all(abs(x-y)<=tolerance for x,y in zip(actual,color)),(name,actual,color)
            print(a.browser,script,'PASS')
        if a.sdl_interop:
            for test,marker in [('sdl_interop','PASS SDL interop:'),('sdl_texture','PASS SDL raster texture:')]:
                page.goto(a.url+'/?script=/tests/'+test+'.das',wait_until='domcontentloaded')
                page.wait_for_function('(s)=>{let t=document.querySelector("#log").textContent;return t.includes(s)||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',arg=marker,timeout=180000)
                log=page.locator('#log').inner_text()
                assert marker in log,log
                assert not errors,errors; require_aot()
                print(a.browser,test+' script/pixel/ownership checks PASS')
        page.goto(a.url,wait_until='domcontentloaded')
        page.wait_for_function('()=>document.querySelector("#log").textContent.includes("PASS frame 3")',timeout=180000)
        record_renderer(page,browser,out/(artifact_tag+'-renderer.json'))
        image=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        # Canvas has an outline, not a layout border; drawing dimensions are 800x600.
        def close(actual,target): return all(abs(x-y)<8 for x,y in zip(actual,target))
        assert close(image.getpixel((100,100)),(54,181,240)),image.getpixel((100,100))
        assert close(image.getpixel((20,20)),(24,28,40)),image.getpixel((20,20))
        image.save(out/(artifact_tag+'-webgl.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'animated WebGL 2 canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/text.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS text frame 3")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS text frame 3' in log and 'missing=0' in log,log
        text_image=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for top,bottom in [(32,72),(105,145),(145,183),(183,220),(220,257),(257,296),(330,380)]:
            ink=sum(1 for y in range(top,bottom) for x in range(40,840)
                    if min(text_image.getpixel((x,y)))>150)
            assert ink>40,(top,bottom,ink)
        text_image.save(out/(artifact_tag+'-text.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'multilingual text canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/drawing.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS drawing frame 3")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS drawing frame 3' in log,log
        gallery=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for point,color in [((100,100),(57,181,240)),((430,100),(255,181,93)),
                            ((120,480),(24,28,40)),((700,275),(24,28,40)),
                            ((300,430),(255,93,98)),((390,430),(80,217,154))]:
            assert close(gallery.getpixel(point),color),(point,gallery.getpixel(point),color)
        gallery.save(out/(artifact_tag+'-drawing.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'drawing/images canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/effects.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS effects frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS effects frame 3' in log,log
        effects=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        left=effects.getpixel((50,100)); right=effects.getpixel((260,100))
        assert left[0]>left[2]+70 and right[2]>right[0]+70,(left,right)
        assert close(effects.getpixel((445,115)),(255,93,98)),effects.getpixel((445,115))
        for point,color in [((50,280),(80,217,154)),((70,280),(57,181,240)),
                            ((347,285),(244,211,109)),((740,300),(201,144,240)),
                            ((155,510),(57,181,240)),((445,510),(160,141,81))]:
            assert close(effects.getpixel(point),color),(point,effects.getpixel(point),color)
        assert effects.getpixel((155,568))[2]>60,effects.getpixel((155,568))
        assert max(effects.getpixel((850,365)))<40,effects.getpixel((850,365))
        effects.save(out/(artifact_tag+'-effects.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'shaders/filters canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/geometry.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS geometry frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS geometry frame 3' in log,log
        geometry=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        expected=[[True,True,True],[False,True,False],[True,False,False],
                  [True,False,True],[False,False,True]]
        for i,filled in enumerate(expected):
            for dx,is_filled in zip([25,69,115],filled):
                point=(28+176*i+dx,107)
                target=(57,181,240) if is_filled else (24,28,40)
                assert close(geometry.getpixel(point),target),(i,point,geometry.getpixel(point),target)
        assert close(geometry.getpixel((112,365)),(255,93,98)),geometry.getpixel((112,365))
        green=yellow=0
        for y in range(260,455):
            for x in range(280,850):
                pixel=geometry.getpixel((x,y))
                green+=int(close(pixel,(80,217,154)))
                yellow+=int(close(pixel,(244,211,109)))
        assert green>700 and yellow>150,(green,yellow)
        geometry.save(out/(artifact_tag+'-geometry.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'path operations/measurement canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/picture.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS picture frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS picture frame 3; recordings=1' in log,log
        pictures=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for point,color in [((70,145),(57,181,240)),((125,148),(80,217,154)),
                            ((185,130),(255,93,98)),((215,130),(244,211,109)),
                            ((185,155),(201,144,240)),((215,155),(57,181,240))]:
            assert close(pictures.getpixel(point),color),(point,pictures.getpixel(point),color)
            restored=(point[0]+300,point[1])
            assert close(pictures.getpixel(restored),color),(restored,pictures.getpixel(restored),color)
        for point,color in [((682,160),(47,135,180)),((98,411),(57,181,240)),
                            ((112,411),(80,217,154)),((140,406),(255,93,98))]:
            assert close(pictures.getpixel(point),color),(point,pictures.getpixel(point),color)
        original_ink=restored_ink=0
        for y in range(198,225):
            for x in range(58,220):
                original_ink+=int(min(pictures.getpixel((x,y)))>150)
                restored_ink+=int(min(pictures.getpixel((x+300,y)))>150)
        assert original_ink>100 and abs(original_ink-restored_ink)<20,(original_ink,restored_ink)
        pictures.save(out/(artifact_tag+'-picture.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'recorded pictures/roundtrip/shader canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/runtime.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS runtime frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS runtime frame 3; compilations=4' in log,log
        runtime=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for point,color in [((700,110),(255,93,98)),((820,110),(98,93,255)),
                            ((700,180),(80,217,154)),((820,180),(154,217,80)),
                            ((160,460),(64,0,191)),((460,460),(128,0,128)),((760,460),(191,0,64))]:
            assert close(runtime.getpixel(point),color),(point,runtime.getpixel(point),color)
        red=[runtime.getpixel((x,y))[0] for y in range(105,255,15) for x in range(60,260,20)]
        assert max(red)-min(red)>140,(min(red),max(red))
        left=runtime.getpixel((360,160)); right=runtime.getpixel((560,160))
        assert right[0]>left[0]+70 and left[2]>right[2]+30,(left,right)
        page.wait_for_timeout(300)
        animated=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        changed=sum(sum(abs(a-b) for a,b in zip(runtime.getpixel((x,y)),animated.getpixel((x,y))))
                    for y in range(105,255,15) for x in range(60,260,20))
        assert changed>50,changed
        animated.save(out/(artifact_tag+'-runtime.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'SkSL shaders/children/color filters/blenders/animation canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/filter_graph.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS filter graph frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS filter graph frame 3; compilations=2' in log,log
        graph=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for point,color in [((100,160),(57,181,240)),((400,160),(240,181,57)),((500,160),(154,217,80)),
                            ((700,160),(126,150,190)),((800,160),(137,215,138)),
                            ((79,449),(57,181,240)),((289,449),(126,150,190)),((709,449),(255,93,98))]:
            assert close(graph.getpixel(point),color),(point,graph.getpixel(point),color)
        left=graph.getpixel((480,449));right=graph.getpixel((600,449))
        assert right[0]>left[0]+60 and left[2]>right[2]+60,(left,right)
        before=graph.crop((340,100,580,260)).tobytes()
        for attempt in range(3):
            page.wait_for_timeout(220+attempt*170)
            animated=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
            changed=sum(abs(a-b) for a,b in zip(before,animated.crop((340,100,580,260)).tobytes()))
            if changed>1000: break
        assert changed>1000,changed
        animated.save(out/(artifact_tag+'-filter-graph.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'runtime image-filter graphs/sources/merge/transform/animation canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/advanced_filters.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS advanced filters frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS advanced filters frame 3' in log,log
        advanced=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for point,color in [((100,125),(57,181,240)),((400,125),(57,181,240)),((700,125),(57,181,240)),
                            ((100,335),(156,137,169)),((770,380),(48,59,82)),((50,505),(125,104,53))]:
            assert close(advanced.getpixel(point),color),(point,advanced.getpixel(point),color)
        tile_blue=sum(int(close(advanced.getpixel((x,y)),(57,181,240)))
                      for y in range(285,425) for x in range(340,580))
        assert tile_blue>5000,tile_blue
        for left,right in [(340,580),(640,880)]:
            values=[advanced.getpixel((x,y))[0] for y in range(500,630,4) for x in range(left+5,right-5,4)]
            assert max(values)>80 and max(values)-min(values)>45,(left,min(values),max(values))
        advanced.save(out/(artifact_tag+'-advanced-filters.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'convolution/displacement/arithmetic/tile/magnifier/lighting canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/paragraph.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS paragraph frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS paragraph frame 3; lines=2; ellipsis=true; missing=0' in log,log
        paragraph=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,680]
        # CSS fractional layout can round a locator screenshot outward by one pixel.
        assert paragraph.width==900 and paragraph.height in (680,681),paragraph.size
        heading=sum(1 for y in range(35,90) for x in range(50,500)
                    if paragraph.getpixel((x,y))[1]>150 and paragraph.getpixel((x,y))[0]<120)
        emphasis=sum(1 for y in range(90,180) for x in range(50,850)
                     if paragraph.getpixel((x,y))[0]>180 and paragraph.getpixel((x,y))[2]<130)
        assert heading>300 and emphasis>150,(heading,emphasis)
        for top,bottom in [(180,400),(455,530),(585,630)]:
            ink=sum(1 for y in range(top,bottom) for x in range(50,850)
                    if min(paragraph.getpixel((x,y)))>150)
            assert ink>150,(top,bottom,ink)
        paragraph.save(out/(artifact_tag+'-paragraph.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'rich paragraphs/styles/multilingual text/ellipsis/RTL canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/selection.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS selection frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS selection frame 3; word_boxes=1; range_boxes=4' in log,log
        assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,580]
        selection=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        blue=sum(1 for y in range(150,260) for x in range(50,850)
                 if close(selection.getpixel((x,y)),(41,78,112)))
        orange=sum(1 for y in range(150,200) for x in range(50,150)
                   if close(selection.getpixel((x,y)),(255,181,93)))
        assert blue>2000 and orange>20,(blue,orange)
        for top,bottom in [(150,270),(335,500)]:
            ink=sum(1 for y in range(top,bottom) for x in range(50,850)
                    if min(selection.getpixel((x,y)))>140)
            assert ink>600,(top,bottom,ink)
        selection.save(out/(artifact_tag+'-selection.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'hit-test probe/word selection/bidi multiline range canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/caret.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS caret frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS caret frame 3; edges=5; wrap=true' in log,log
        assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,580]
        caret=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        orange=sum(1 for y in range(140,380) for x in range(45,490)
                   if close(caret.getpixel((x,y)),(255,181,93)))
        green=sum(1 for y in range(175,380) for x in range(45,490)
                  if close(caret.getpixel((x,y)),(80,217,154)))
        ink=sum(1 for y in range(140,480) for x in range(520,850)
                if min(caret.getpixel((x,y)))>140)
        assert orange>200 and green>40 and ink>500,(orange,green,ink)
        caret.save(out/(artifact_tag+'-caret.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'grapheme edges/RTL/soft-wrap caret affinity canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/inline_layout.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS inline layout frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS inline layout frame 3; objects=3' in log,log
        assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,680]
        inline=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for color in [(57,181,240),(255,181,93),(80,217,154)]:
            pixels=sum(1 for y in range(150,300) for x in range(50,850)
                       if close(inline.getpixel((x,y)),color))
            assert pixels>350,(color,pixels)
        # Default lines fit above 490; fixed strut has a third line near 520.
        left_low=sum(1 for y in range(510,560) for x in range(50,400)
                     if min(inline.getpixel((x,y)))>140)
        right_low=sum(1 for y in range(510,560) for x in range(470,830)
                      if min(inline.getpixel((x,y)))>140)
        assert left_low==0 and right_low>150,(left_low,right_low)
        inline.save(out/(artifact_tag+'-inline-layout.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'inline placeholders/caller rendering/strut line grid canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/text_style.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS text style frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS text style frame 3' in log,log
        assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,680]
        text_style=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        cool=warm=background=0
        for y in range(130,220):
            for x in range(50,650):
                r,g,b=text_style.getpixel((x,y))
                cool+=int(b>150 and b>r+20)
                warm+=int(r>180 and b<160 and g>120)
                background+=int(close((r,g,b),(41,78,112)))
        assert cool>400 and warm>200 and background>1500,(cool,warm,background)
        stroke=sum(1 for y in range(245,330) for x in range(50,650)
                   if close(text_style.getpixel((x,y)),(255,181,93)))
        assert stroke>400,stroke
        left=sum(1 for x in range(50,450) if close(text_style.getpixel((x,496)),(57,181,240)))
        right=sum(1 for x in range(470,870) if close(text_style.getpixel((x,496)),(255,181,93)))
        assert left>250 and right>left+10,(left,right)
        text_style.save(out/(artifact_tag+'-text-style.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'text paint gradient/background/stroke/OpenType advance canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/typography.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS typography frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS typography frame 3; decorations=5' in log,log
        assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,760]
        typography=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        changed=sum(1 for y in range(120,245) for x in range(50,430)
                    if typography.getpixel((x,y))!=typography.getpixel((x+420,y)))
        assert changed>500,changed
        for start in [50,210,370,530,690]:
            blue=sum(1 for y in range(275,325) for x in range(start,start+145)
                     if typography.getpixel((x,y))[2]>150 and typography.getpixel((x,y))[0]<100)
            assert blue>30,(start,blue)
        red=sum(1 for y in range(380,470) for x in range(40,480)
                if typography.getpixel((x,y))[0]>150 and typography.getpixel((x,y))[1]<130)
        blue=sum(1 for y in range(380,470) for x in range(40,480)
                 if typography.getpixel((x,y))[2]>110 and typography.getpixel((x,y))[0]<110)
        gold=sum(1 for y in range(370,470) for x in range(500,850)
                 if close(typography.getpixel((x,y)),(255,181,93)))
        assert red>150 and blue>150 and gold>50,(red,blue,gold)
        typography.save(out/(artifact_tag+'-typography.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'variable outlines/TTC/decorations/shadows/baseline/height canvas pixels PASS')
        if a.sdl_interop:
            page.goto(a.url+'/?script=/examples/sdl_interop.das',wait_until='domcontentloaded')
            page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS SDL interop frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
            log=page.locator('#log').inner_text()
            assert 'PASS SDL interop frame 3; host owns events and swap' in log,log
            assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,600]
            interop=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
            assert close(interop.getpixel((100,40)),(57,181,240)),interop.getpixel((100,40))
            assert close(interop.getpixel((830,540)),(57,181,240)),interop.getpixel((830,540))
            ink=sum(1 for y in range(85,440) for x in range(50,850) if min(interop.getpixel((x,y)))>140)
            assert ink>1500,ink
            interop.save(out/(artifact_tag+'-sdl-interop.png'))
            assert not errors,errors; require_aot()
            print(a.browser,'dasSDL3-owned window/context, host event loop/swap canvas pixels PASS')
        if a.sdl_interop:
            page.goto(a.url+'/?script=/examples/sdl_texture.das',wait_until='domcontentloaded')
            page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS SDL raster texture frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
            log=page.locator('#log').inner_text()
            assert 'PASS SDL raster texture frame 3' in log,log
            assert page.locator('canvas').evaluate('(c)=>[c.width,c.height]')==[900,600]
            raster=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
            assert close(raster.getpixel((100,40)),(57,181,240)),raster.getpixel((100,40))
            assert close(raster.getpixel((10,10)),(24,28,40)),raster.getpixel((10,10))
            assert close(raster.getpixel((830,540)),(140,105,67)),raster.getpixel((830,540))
            ink=sum(1 for y in range(85,440) for x in range(50,850) if min(raster.getpixel((x,y)))>140)
            assert ink>1500,ink
            raster.save(out/(artifact_tag+'-sdl-texture.png'))
            assert not errors,errors; require_aot()
            print(a.browser,'Skia CPU raster -> SDL_Texture -> host SDL_Renderer canvas pixels PASS')
        page.goto(a.url+'/?script=/examples/codecs.das',wait_until='domcontentloaded')
        page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("PASS codecs frame 3")||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',timeout=180000)
        log=page.locator('#log').inner_text()
        assert 'PASS codecs frame 3' in log and 'CODEC_BYTES' in log,log
        codecs=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
        for pos,color in [((70,150),(57,181,240)),((654,150),(57,181,240)),((362,400),(57,181,240)),((522,510),(98,108,128)),((814,260),(0,0,0))]:
            assert close(codecs.getpixel(pos),color),(pos,codecs.getpixel(pos),color)
        codecs.save(out/(artifact_tag+'-codecs.png'))
        assert not errors,errors; require_aot()
        print(a.browser,'PNG/JPEG/WebP lossy/lossless/alpha gallery canvas pixels PASS')
        for key,payload_bytes in [('picture',native_picture_bytes),('filter-graph',native_graph_bytes),('advanced-filters',native_advanced_bytes)]:
            if not payload_bytes: continue
            # Test-only HTML routes supply native SKP data before the WASM main runs.
            payload=base64.b64encode(payload_bytes).decode('ascii')
            filename=key+'-interchange.skp'
            injection='Module.preRun=[()=>FS.writeFile('+json.dumps(filename)+',Uint8Array.from(atob('+json.dumps(payload)+'),c=>c.charCodeAt(0)))];'
            html=(root/'web/index.html').read_text(encoding='utf-8').replace('@DASSKIA_SDL3_LINK@','').replace(
                '</script><script src="dasSkia_runner.js">',injection+'</script><script src="dasSkia_runner.js">')
            if a.strict_aot: html=html.replace('dasSkia_runner.js','dasSkia_web_aot_runner.js')
            document=key+'-interchange.html'
            page.route('**/'+document+'**',serve_html(html))
            response=page.goto(a.url+'/'+document+'?script=/tests/'+key.replace('-','_')+'_interchange.das',wait_until='domcontentloaded')
            assert response and response.ok,'Interchange test document failed to load'
            expected_interchange='PASS '+key.replace('-',' ')+' interchange:'
            page.wait_for_function('(s)=>{let t=document.querySelector("#log").textContent;return t.includes(s)||t.includes("FAIL")||t.includes("error[")||t.includes("Aborted")}',arg=expected_interchange,timeout=180000)
            log=page.locator('#log').inner_text()
            assert expected_interchange in log,log
            assert not errors,errors; require_aot()
            print(a.browser,'native -> WASM '+key.replace('-',' ')+' interchange PASS')
        if a.strict_aot:
            lifecycles=['codecs','window','text','drawing','effects','geometry','picture','runtime','filter_graph','advanced_filters','paragraph','selection','caret','inline_layout','text_style','typography']
            if a.sdl_interop: lifecycles.extend(['sdl_interop','sdl_texture'])
            for name in lifecycles:
                page.goto(a.url+'/?script=/examples/'+name+'.das&smoke=1',wait_until='domcontentloaded')
                page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("app_quit AOT=yes")||t.includes("FAIL")||t.includes("error[")||t.includes("Missing AOT")||t.includes("Aborted")}',timeout=180000)
                log=page.locator('#log').inner_text()
                require_aot()
                assert 'app_quit AOT=yes; fallback disabled' in log and 'FAIL' not in log and 'error[' not in log,log
                assert not errors,errors
                print(a.browser,'strict lifecycle including app_quit',name,'PASS')
            for name,forbidden,required in [
                ('aot_missing','FAIL INTERPRETER FALLBACK EXECUTED','AOT link failed'),
                ('aot_import_missing','FAIL IMPORT FALLBACK EXECUTED','AOT link failed')]:
                page.goto(a.url+'/?script=/tests/'+name+'.das',wait_until='domcontentloaded')
                page.wait_for_function('()=>{let t=document.querySelector("#log").textContent;return t.includes("error[")||t.includes("Missing AOT")||t.includes("FALLBACK EXECUTED")||t.includes("Aborted")}',timeout=180000)
                log=page.locator('#log').inner_text()
                assert 'STRICT_AOT=1; fallback disabled' in log and required in log,log
                if name=='aot_import_missing': assert 'aot_unlinked' in log,log
                assert not any(line.startswith(forbidden) for line in log.splitlines()) and 'main AOT=yes' not in log,log
                (out/(artifact_tag+'-'+name+'.log')).write_text(log,encoding='utf-8')
                print(a.browser,'negative AOT artifact oracle',name,'PASS')
    finally:
        browser.close()
