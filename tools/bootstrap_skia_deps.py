from pathlib import Path
import subprocess, sys, argparse
root=Path(__file__).resolve().parents[1]
skia=root/'third_party/skia'
ns={}
exec('def Var(x): return vars[x]\n'+(skia/'DEPS').read_text(),ns)
names=['libpng','zlib','freetype','harfbuzz','icu','libjpeg-turbo','libwebp']
p=argparse.ArgumentParser();p.add_argument('--only',nargs='+',choices=names)
a=p.parse_args()
for name in a.only or names:
    dest=skia/'third_party/externals'/name
    spec=ns['deps']['third_party/externals/'+name]
    url,rev=spec.rsplit('@',1)
    dest.mkdir(parents=True,exist_ok=True)
    def run(*a): subprocess.run(a,cwd=dest,check=True)
    run('git','init')
    if subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=dest,text=True).strip():
        raise SystemExit('Dependency has local changes: '+str(dest))
    run('git','fetch','--depth','1',url,rev)
    run('git','checkout','--detach','FETCH_HEAD')
if not a.only or not (skia/'bin/gn.exe').exists():
    subprocess.run([sys.executable,str(skia/'bin/fetch-gn')],check=True)
