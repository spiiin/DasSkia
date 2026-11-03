"""Windows CI stages. No project cache is restored; stages also run locally."""
import argparse,hashlib,json,os,shutil,subprocess,sys,urllib.request,zipfile
from pathlib import Path,PurePosixPath
ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'
LOGS=BUILD/'logs';LOGS.mkdir(parents=True,exist_ok=True)
LOCK=json.loads((ROOT/'ci/toolchains.json').read_text())
DEPS=json.loads((ROOT/'dependencies.json').read_text())

def run(args,name,env=None,cwd=ROOT):
    if not isinstance(args,str):args=[str(a) for a in args]
    print(name+': '+(args if isinstance(args,str) else subprocess.list2cmdline(args)),flush=True)
    path=LOGS/(name+'.log')
    with path.open('w',encoding='utf-8') as log:
        result=subprocess.run(args,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:
        print(path.read_text(encoding='utf-8',errors='replace')[-18000:],flush=True)
        raise subprocess.CalledProcessError(result.returncode,args)

def git_revision(path):
    return subprocess.check_output(['git','rev-parse','HEAD'],cwd=path,text=True).strip()

def fetch(repo,path,name):
    if path.exists() and any(path.iterdir()):raise RuntimeError('Refusing to reuse dependency checkout: '+str(path))
    path.mkdir(parents=True,exist_ok=True)
    run(['git','init'],name+'-init',cwd=path)
    run(['git','fetch','--depth','1',repo['url'],repo['revision']],name+'-fetch',cwd=path)
    run(['git','checkout','--detach','FETCH_HEAD'],name+'-checkout',cwd=path)
    if git_revision(path)!=repo['revision']:raise RuntimeError('Wrong dependency revision: '+name)

def audit(profile=None):
    report={}
    repos=[(n,ROOT/'third_party'/n,DEPS[n]['revision']) for n in ['skia','daScript','dasSDL3']]
    ns={};exec('def Var(x): return vars[x]\n'+(ROOT/'third_party/skia/DEPS').read_text(),ns)
    for n in ['libpng','zlib','freetype','harfbuzz','icu','libjpeg-turbo','libwebp']:
        repos.append((n,ROOT/'third_party/skia/third_party/externals'/n,ns['deps']['third_party/externals/'+n].rsplit('@',1)[1]))
    if profile:repos.append(('SDL3-'+profile,BUILD/profile/'_deps/sdl3-src',DEPS['SDL3']['revision']))
    for name,path,expected in repos:
        actual=git_revision(path)
        dirty=subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=path,text=True).strip()
        if actual!=expected or dirty:raise RuntimeError('Dependency revision/source mismatch: '+name)
        report[name]=actual
    (LOGS/('dependencies-'+(profile or 'bootstrap')+'.json')).write_text(json.dumps(report,indent=2)+'\n')

def bootstrap():
    for path in [ROOT/'third_party',*[BUILD/n for n in ['desktop','web','skia-native','skia-web']]]:
        if path.exists() and any(path.iterdir()):raise RuntimeError('Clean build required; refusing existing '+str(path))
    run([sys.executable,'tools/bootstrap.py'],'bootstrap')
    fetch(DEPS['dasSDL3'],ROOT/'third_party/dasSDL3','bootstrap-dassdl3')
    audit()
    info={'source_root':str(ROOT),'clean_start':True}
    if os.environ.get('GITHUB_ACTIONS')=='true':
        info['commit']=git_revision(ROOT)
        if info['commit']!=os.environ['GITHUB_SHA']:raise RuntimeError('Checkout differs from workflow SHA')
    (LOGS/'clean-start.json').write_text(json.dumps(info,indent=2)+'\n')

def build_desktop(jobs):
    run([sys.executable,'tools/build_skia.py','--jobs',jobs],'skia-desktop')
    run(['cmake','-S',ROOT,'-B',BUILD/'desktop','-G','Ninja','-DCMAKE_BUILD_TYPE=Release',
         '-DDASSKIA_AOT_TESTS=ON','-DDASSKIA_WITH_DASSDL3=ON','-DDASSKIA_DASSDL3_ROOT='+str(ROOT/'third_party/dasSDL3')],'configure-desktop')
    audit('desktop')
    run(['cmake','--build',BUILD/'desktop','--parallel',jobs],'build-desktop')

def download(item,folder):
    path=folder/item['url'].rsplit('/',1)[1];folder.mkdir(parents=True,exist_ok=True)
    if not path.exists():
        req=urllib.request.Request(item['url'],headers={'User-Agent':'dasSkia-CI'})
        with urllib.request.urlopen(req,timeout=120) as response,path.open('wb') as output:shutil.copyfileobj(response,output)
    if hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:raise RuntimeError('Tool archive SHA-256 mismatch: '+path.name)
    return path

def software_env():
    env=os.environ.copy()
    env.update({'GALLIUM_DRIVER':'llvmpipe','LIBGL_ALWAYS_SOFTWARE':'true','SDL_RENDER_DRIVER':'software',
                'DASSKIA_REQUIRE_SOFTWARE_GL':'1','DASSKIA_CI_SOFTWARE_RENDERING':'1'})
    return env

def prepare_mesa():
    archive=download(LOCK['mesa'],BUILD/'ci-tools')
    dest=BUILD/'ci-tools/mesa';dest.mkdir(parents=True,exist_ok=True)
    # Runner tar builds do not all include LZMA. Use the pinned standalone
    # 7zr and flatten just the requested file, without extracting archive paths.
    extractor=download(LOCK['7zr'],BUILD/'ci-tools'/('7zip-'+LOCK['7zr']['version']))
    run([extractor,'e',archive,'opengl32.dll','-o'+str(dest),'-y'],'extract-mesa')
    dll=dest/'opengl32.dll'
    if not dll.is_file():raise RuntimeError('Mesa archive has no opengl32.dll')
    for folder in [BUILD/'desktop',BUILD/'desktop/bin']:
        if not folder.is_dir():raise RuntimeError('Build native targets before applying per-app Mesa')
        shutil.copy2(dll,folder/dll.name)
    (LOGS/'mesa.json').write_text(json.dumps({'archive':LOCK['mesa'],
        'dll_sha256':hashlib.sha256(dll.read_bytes()).hexdigest(),'deployment':'per-app build/desktop and bin only'},indent=2)+'\n')

def test_desktop():
    prepare_mesa()
    run(['ctest','--test-dir',BUILD/'desktop','--output-on-failure','--timeout','120',
         '--output-junit',LOGS/'ctest-results.xml'],'ctest',software_env())

def batch_command(path,args=(),capture_env=False):
    # Pass cmd its command line verbatim: list2cmdline's backslash-escaped
    # quotes are not cmd.exe escaping. /s strips the outer payload quotes.
    payload='call "'+str(path.resolve())+'"'
    if args:payload+=' '+subprocess.list2cmdline([str(a) for a in args])
    if capture_env:payload+=' >nul && set'
    comspec=os.environ.get('COMSPEC',r'C:\Windows\System32\cmd.exe')
    return '"'+comspec+'" /d /s '+('/u ' if capture_env else '')+'/c "'+payload+'"'

def setup_emsdk():
    if LOCK['emsdk']['version']!=DEPS['emscripten']:raise RuntimeError('Emsdk lock differs from dependency version')
    sdk=BUILD/'emsdk'
    if (sdk/'.git').exists():
        if git_revision(sdk)!=LOCK['emsdk']['revision'] or subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=sdk,text=True).strip():
            raise RuntimeError('Existing SDK checkout differs from lock')
    else:fetch(LOCK['emsdk'],sdk,'emsdk')
    for command in ['install','activate']:
        run(batch_command(sdk/'emsdk.bat',[command,DEPS['emscripten']]),'emsdk-'+command)

def sdk_environment(sdk):
    # Capture activation privately as Unicode; never log inherited secrets.
    proc=subprocess.run(batch_command(sdk/'emsdk_env.bat',capture_env=True),
                        stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
    env=os.environ.copy()
    for line in proc.stdout.decode('utf-16-le').splitlines():
        if '=' in line and not line.startswith('='):
            key,value=line.split('=',1);env[key]=value
    return env

def build_web(jobs,sdk):
    node=os.environ.get('DASSKIA_NODE') or shutil.which('node')
    if not node or subprocess.check_output([node,'--version'],text=True).strip()!='v'+LOCK['node']:
        raise RuntimeError('Set DASSKIA_NODE to validated Node '+LOCK['node'])
    env=sdk_environment(sdk)
    version=subprocess.check_output([sys.executable,str(sdk/'upstream/emscripten/emcc.py'),'--version'],env=env,text=True)
    if DEPS['emscripten'] not in version.splitlines()[0]:raise RuntimeError('Unexpected Emscripten version')
    run([sys.executable,'tools/build_skia.py','--web','--emsdk',sdk,'--jobs',jobs],'skia-web',env)
    run([sys.executable,sdk/'upstream/emscripten/emcmake.py','cmake','-S',ROOT,'-B',BUILD/'web','-G','Ninja',
         '-DCMAKE_BUILD_TYPE=Release','-DCMAKE_EXE_LINKER_FLAGS=-O1','-DDASSKIA_WEB_AOT=ON','-DDASSKIA_WITH_DASSDL3=ON',
         '-DDASSKIA_DASSDL3_ROOT='+str(ROOT/'third_party/dasSDL3'),'-DDASSKIA_NODE='+node],'configure-web',env)
    audit('web')
    run(['cmake','--build',BUILD/'web','--target','dasSkia_runner','dasSkia_web_aot_runner','--parallel',jobs],'build-web',env)

def lint():
    workflow=(ROOT/'.github/workflows/ci.yml').read_text()
    for name in ['checkout','setup-python','setup-node','upload-artifact']:
        if 'actions/'+name+'@'+LOCK['actions/'+name]['revision'] not in workflow:raise RuntimeError('Action pin mismatch: '+name)
    for field,key in [('python-version','python'),('node-version','node')]:
        if field+": '"+LOCK[key]+"'" not in workflow:raise RuntimeError('Workflow tool version mismatch: '+key)
    expected={'cmake':LOCK['cmake'],'ninja':LOCK['ninja'],**LOCK['pip']}
    actual=dict(line.split('==') for line in (ROOT/'ci/requirements.txt').read_text().splitlines() if line)
    if actual!=expected:raise RuntimeError('CI Python package lock mismatch')
    archive=download(LOCK['actionlint'],BUILD/'ci-tools');dest=BUILD/'ci-tools/actionlint';dest.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            if PurePosixPath(name).is_absolute() or '..' in PurePosixPath(name).parts or ':' in name or chr(92) in name:raise RuntimeError('Unsafe actionlint archive path')
        z.extractall(dest)
    run([dest/'actionlint.exe','-color','.github/workflows/ci.yml'],'actionlint')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('stage',choices=['bootstrap','build-desktop','test-desktop','setup-emsdk','build-web','test-web','lint'])
    p.add_argument('--jobs',default='6')
    p.add_argument('--emsdk',type=Path,default=BUILD/'emsdk')
    p.add_argument('--firefox-executable')
    a=p.parse_args()
    if a.stage=='bootstrap':bootstrap()
    elif a.stage=='build-desktop':build_desktop(a.jobs)
    elif a.stage=='test-desktop':test_desktop()
    elif a.stage=='setup-emsdk':setup_emsdk()
    elif a.stage=='build-web':build_web(a.jobs,a.emsdk.resolve())
    elif a.stage=='test-web':
        args=[sys.executable,'tools/ci_browser_checks.py']
        if a.firefox_executable:args+=['--firefox-executable',a.firefox_executable]
        run(args,'browser-driver',software_env())
    elif a.stage=='lint':lint()
if __name__=='__main__':main()
