"""Resize and input regression for the shared SDL_Renderer raster example."""
import argparse,io,re
from PIL import Image
from playwright.sync_api import sync_playwright
from web_browser import launch_browser
p=argparse.ArgumentParser()
p.add_argument('--url',default='http://127.0.0.1:8100')
p.add_argument('--browser',choices=['chromium','firefox'],default='chromium')
p.add_argument('--executable')
p.add_argument('--strict-aot',action='store_true')
a=p.parse_args()
with sync_playwright() as pw:
 b=launch_browser(pw,a.browser,a.executable)
 try:
  page=b.new_page(viewport={'width':1100,'height':1000});errors=[]
  page.on('pageerror',lambda e:errors.append(str(e)))
  def document(route):
   response=route.fetch();body=response.text().replace('<canvas id=','<canvas style="width:900px;height:600px;max-width:none" id=')
   route.fulfill(response=response,body=body)
  page.route(re.compile(r'.*[?]script=.*'),document)
  page.goto(a.url+'/?script=/examples/sdl_texture.das')
  page.wait_for_function("document.querySelector('#log').textContent.includes('PASS SDL raster texture frame 3')",timeout=120000)
  for w,h in [(640,480),(0,0),(900,600)]:
   page.evaluate("([w,h])=>{let c=document.querySelector('canvas');c.style.width=w+'px';c.style.height=h+'px';window.dispatchEvent(new Event('resize'));}",[w,h])
   page.wait_for_function('([w,h])=>{let c=document.querySelector("canvas");return c.width===w&&c.height===h}',arg=[w,h])
   page.evaluate('()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
   log=page.locator('#log').inner_text();assert 'FAIL' not in log and 'error[' not in log and not errors,(log,errors)
   assert page.evaluate('MainLoop.func!==null')
   if w:
    im=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
    for pos,color in [((100,40),(57,181,240)),((10,10),(24,28,40)),((w-70,h-60),(140,105,67))]:
     actual=im.getpixel(pos);assert all(abs(x-y)<=3 for x,y in zip(actual,color)),(pos,actual,color)
  page.locator('canvas').focus();page.keyboard.press('Escape')
  page.wait_for_function('MainLoop.func===null&&MainLoop.scheduler===null')
  log=page.locator('#log').inner_text()
  if a.strict_aot:
   for marker in ['STRICT_AOT=1; fallback disabled','app_init AOT=yes','app_frame AOT=yes','app_quit AOT=yes']:assert marker in log,log
  assert 'FAIL' not in log and not errors,(log,errors)
  print(a.browser,'strict AOT' if a.strict_aot else 'interpreter','SDL texture resize/zero-size/alpha pixels/Escape PASS')
 finally:b.close()
