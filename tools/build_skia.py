from pathlib import Path
import argparse, os, shutil, subprocess, sys, json
p=argparse.ArgumentParser(); p.add_argument('--web',action='store_true'); p.add_argument('--emsdk',default='C:/src/emsdk'); p.add_argument('--jobs',default='6'); a=p.parse_args()
r=Path(__file__).resolve().parents[1]; s=r/'third_party/skia'; out=r/'build'/('skia-web' if a.web else 'skia-native')
os.environ['TEMP']=os.environ['TMP']=str(r/'build/tmp'); Path(os.environ['TEMP']).mkdir(parents=True,exist_ok=True)
args='''is_official_build=true is_debug=false is_component_build=false is_trivial_abi=false skia_enable_ganesh=true skia_enable_graphite=false skia_enable_tools=false skia_enable_pdf=false skia_enable_skottie=false skia_enable_svg=false skia_use_gl=true skia_use_vulkan=false skia_use_dawn=false skia_use_webgpu=false skia_use_icu=false skia_use_harfbuzz=false skia_use_freetype=false skia_use_fontconfig=false skia_use_expat=false skia_use_piex=false skia_use_wuffs=false skia_use_libjpeg_turbo_decode=true skia_use_libjpeg_turbo_encode=true skia_use_libwebp_decode=true skia_use_libwebp_encode=true skia_use_libpng_decode=true skia_use_libpng_encode=true skia_use_system_libpng=false skia_use_system_zlib=false skia_use_zlib=true skia_use_xps=false skia_use_fonthost_mac=false skia_enable_fontmgr_empty=true'''
args=args.replace('skia_use_icu=false','skia_use_icu=true').replace('skia_use_harfbuzz=false','skia_use_harfbuzz=true').replace('skia_use_freetype=false','skia_use_freetype=true')
args+=' skia_use_system_libjpeg_turbo=false skia_use_system_libwebp=false skia_use_system_icu=false skia_use_system_harfbuzz=false skia_use_system_freetype2=false skia_use_freetype_woff2=false skia_enable_fontmgr_custom_empty=true skia_enable_skshaper=true skia_enable_skparagraph=true'
if a.web:
    args+=' target_os="wasm" target_cpu="wasm" skia_emsdk_dir="'+a.emsdk.replace('\\','/')+'" skia_enable_fontmgr_win=false extra_cflags=["-msimd128", "-fwasm-exceptions", "-sWASM_LEGACY_EXCEPTIONS=0", "-include", "'+(r/'src/skia_webgl_compat.h').as_posix()+'"]'
    args+=' cc_wrapper='+json.dumps(subprocess.list2cmdline([sys.executable,(r/'tools/emscripten_cc.py').as_posix()]).replace('\\','/'))
else:
    vs=subprocess.check_output([os.environ.get('ProgramFiles(x86)','C:/Program Files (x86)')+'/Microsoft Visual Studio/Installer/vswhere.exe','-latest','-property','installationPath'],text=True).strip().replace('\\','/')
    args+=' win_vc="'+vs+'/VC" extra_cflags=["/MD"]'
ninja=shutil.which('ninja') or 'C:/msvs17.8/2022/Professional/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe'
out.mkdir(parents=True,exist_ok=True); (out/'args.gn').write_text(args+'\n')
subprocess.run([str(s/'bin/gn.exe'),'gen',str(out)],cwd=s,check=True)
subprocess.run([ninja,'-C',str(out),'-j',a.jobs,'skia','modules/skparagraph:skparagraph','modules/skshaper:skshaper','modules/skunicode:skunicode_icu'],cwd=s,check=True)
