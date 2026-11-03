"""Prepare the already-tested strict AOT package for GitHub Pages."""
import hashlib,json,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SITE=ROOT/'build/web/aot-site'

def main():
    files=['index.html','dasSkia_web_aot_runner.js','dasSkia_web_aot_runner.wasm','dasSkia_web_aot_runner.data']
    for name in files:
        if not (SITE/name).is_file():raise RuntimeError('Missing strict AOT package file: '+name)
    html=(SITE/'index.html').read_text(encoding='utf-8')
    if 'src="dasSkia_web_aot_runner.js"' not in html or 'src="dasSkia_runner.js"' in html:
        raise RuntimeError('Pages must load the strict AOT runner using a relative URL')
    if b'STRICT_AOT=1; fallback disabled' not in (SITE/files[2]).read_bytes():
        raise RuntimeError('WASM package has no strict AOT marker')
    notices={
        'Skia.txt':'third_party/skia/LICENSE','daScript.txt':'third_party/daScript/LICENSE',
        'SDL3.txt':'build/web/_deps/sdl3-src/LICENSE.txt',
        'FreeType.txt':'third_party/skia/third_party/externals/freetype/docs/FTL.TXT',
        'HarfBuzz.txt':'third_party/skia/third_party/externals/harfbuzz/COPYING',
        'ICU.txt':'third_party/skia/third_party/externals/icu/LICENSE',
        'libpng.txt':'third_party/skia/third_party/externals/libpng/LICENSE',
        'zlib.txt':'third_party/skia/third_party/externals/zlib/LICENSE',
        'DejaVu.txt':'assets/fonts/LICENSE','Distortable-OFL.txt':'assets/fonts/Distortable-OFL.txt'}
    shutil.copytree(ROOT/'licenses',SITE/'licenses',dirs_exist_ok=True)
    for name,source in notices.items():shutil.copy2(ROOT/source,SITE/'licenses'/name)
    for name in ['LICENSE','THIRD_PARTY_NOTICES.md']:shutil.copy2(ROOT/name,SITE/name)
    info={'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
          'strict_aot':True,'files':{name:hashlib.sha256((SITE/name).read_bytes()).hexdigest() for name in files}}
    (SITE/'build.json').write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
    print('Prepared strict AOT demo:',info['commit'])
if __name__=='__main__':main()
