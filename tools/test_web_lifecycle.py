"""Exercise real context loss/restore and CSS drawable resize in the browser."""
import argparse,io,re
from PIL import Image
from playwright.sync_api import sync_playwright
from web_browser import launch_browser
p=argparse.ArgumentParser()
p.add_argument('--url',default='http://127.0.0.1:8100')
p.add_argument('--browser',choices=['chromium','firefox'],default='chromium')
p.add_argument('--executable')
p.add_argument('--strict-aot',action='store_true')
p.add_argument('--sdl-interop',action='store_true')
a=p.parse_args()
with sync_playwright() as pw:
 browser=launch_browser(pw,a.browser,a.executable)
 try:
  for name,expected,point,marker in [('window',(54,181,240),(100,100),'PASS frame 3')]+([('sdl_interop',(57,181,240),(100,40),'PASS SDL interop frame 3')] if a.sdl_interop else []):
   page=browser.new_page(viewport={'width':1100,'height':1000});errors=[]
   page.on('pageerror',lambda e:errors.append(str(e)))
   def document(route):
    response=route.fetch()
    # An embedding host may give SDL externally controlled CSS dimensions.
    body=response.text().replace('<canvas id=', '<canvas style="width:800px;height:600px;max-width:none" id=')
    route.fulfill(response=response,body=body)
   page.route(re.compile(r'.*[?]script=.*'),document)
   page.goto(a.url+'/?script=/examples/'+name+'.das')
   page.wait_for_function("s=>document.querySelector('#log').textContent.includes(s)",arg=marker,timeout=120000)
   def healthy():
    log=page.locator('#log').inner_text()
    assert 'FAIL' not in log and 'error[' not in log and not errors,(log,errors)
    assert page.evaluate('MainLoop.func!==null'),log
    if a.strict_aot:
     for m in ['STRICT_AOT=1; fallback disabled','app_init AOT=yes','app_frame AOT=yes']: assert m in log,log
   def pixels():
    page.evaluate('()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
    im=Image.open(io.BytesIO(page.locator('canvas').screenshot())).convert('RGB')
    color=im.getpixel(point)
    assert all(abs(x-y)<=3 for x,y in zip(color,expected)),(name,color,expected)
   healthy();pixels()
   page.evaluate("""()=>{window.testGL=document.querySelector('canvas').getContext('webgl2');window.loss=testGL.getExtension('WEBGL_lose_context');if(!loss)throw Error('WEBGL_lose_context unavailable');window.hostLossCount=0;window.hostRestoreCount=0;testGL.canvas.addEventListener('webglcontextlost',()=>hostLossCount++);testGL.canvas.addEventListener('webglcontextrestored',()=>hostRestoreCount++);}""")
   for cycle in range(2):
    page.evaluate('loss.loseContext()')
    page.wait_for_function('testGL.isContextLost() && hostLossCount>hostRestoreCount')
    page.wait_for_timeout(200);healthy()
    page.evaluate('loss.restoreContext()')
    page.wait_for_function('!testGL.isContextLost() && hostLossCount===hostRestoreCount',timeout=30000)
    healthy();pixels()
   # Restore while WASM frames are paused: event generations must invalidate
   # Ganesh even when no prepare call observes the context in its lost state.
   page.evaluate('MainLoop.pause()')
   page.evaluate('()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
   page.evaluate('loss.loseContext()')
   page.wait_for_function('testGL.isContextLost() && hostLossCount>hostRestoreCount')
   page.wait_for_timeout(200)
   page.evaluate('loss.restoreContext()')
   page.wait_for_function('!testGL.isContextLost() && hostLossCount===hostRestoreCount',timeout=30000)
   page.evaluate('MainLoop.resume()')
   healthy();pixels()
   assert page.evaluate('testGL.__dasSkiaLifecycle.generation===3 && testGL.__dasSkiaLifecycle.refs===1')
   # Shrinking CSS to zero is a temporarily nondrawable frame, not an error.
   for w,h in [(0,0),(640,480),(800,600)]:
    page.evaluate("([w,h])=>{let c=document.querySelector('canvas');c.style.width=w+'px';c.style.height=h+'px';window.dispatchEvent(new Event('resize'));}",[w,h])
    page.wait_for_function('([w,h])=>{let c=document.querySelector("canvas");return c.width===w && c.height===h}',arg=[w,h],timeout=10000)
    page.wait_for_timeout(100);healthy()
    if w: pixels()
   page.locator('canvas').focus();page.keyboard.press('Escape')
   page.wait_for_function('MainLoop.func===null && MainLoop.scheduler===null',timeout=10000)
   log=page.locator('#log').inner_text()
   if a.strict_aot: assert 'app_quit AOT=yes' in log,log
   assert not errors and 'FAIL' not in log,(errors,log)
   assert page.evaluate('testGL.__dasSkiaLifecycle===undefined'), 'context observer leaked after quit'
   print(a.browser,'strict AOT' if a.strict_aot else 'interpreter',name,'three real losses/restores including between frames, host handlers, zero-size/resize pixels, Escape/observer cleanup PASS',flush=True)
   page.close()
 finally: browser.close()
