"""Shared launch policy for ephemeral browser tests; ordinary local runs unchanged."""
import json,os

def launch_browser(pw,name,executable=None):
    options={'headless':True,'executable_path':executable}
    if os.environ.get('DASSKIA_CI_SOFTWARE_RENDERING')=='1':
        if name=='chromium':
            options['args']=['--use-angle=swiftshader','--enable-unsafe-swiftshader']
        else:
            options['firefox_user_prefs']={'webgl.force-enabled':True,'webgl.disable-angle':False,
                'webgl.angle.force-warp':True,'gfx.webrender.software':True}
    return getattr(pw,name).launch(**options)

def record_renderer(page,browser,output):
    info=page.locator('canvas').evaluate("""c=>{let gl=c.getContext('webgl2');if(!gl)throw Error('WebGL 2 unavailable');
        let ext=gl.getExtension('WEBGL_debug_renderer_info');
        return {version:gl.getParameter(gl.VERSION),renderer:gl.getParameter(gl.RENDERER),
          unmasked:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null};}""")
    info['browser_version']=browser.version
    info['software_requested']=os.environ.get('DASSKIA_CI_SOFTWARE_RENDERING')=='1'
    output.write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
