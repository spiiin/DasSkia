"""Full browser matrix and focused checks with scoped localhost servers."""
import argparse,functools,http.server,json,subprocess,sys,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LOGS=ROOT/'build/logs';LOGS.mkdir(parents=True,exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*args):pass

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--firefox-executable');a=p.parse_args()
    servers=[];results=[]
    try:
        urls={}
        for strict,folder in [(False,'site'),(True,'aot-site')]:
            path=ROOT/'build/web'/folder
            if not (path/'index.html').exists():raise RuntimeError('Missing browser package: '+str(path))
            server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(path)))
            servers.append(server);threading.Thread(target=server.serve_forever,daemon=True).start()
            urls[strict]='http://127.0.0.1:'+str(server.server_address[1])
        for browser in ['chromium','firefox']:
            for strict in [False,True]:
                common=['--url',urls[strict],'--browser',browser]
                if strict:common+=['--strict-aot']
                if browser=='firefox' and a.firefox_executable:common+=['--executable',a.firefox_executable]
                tag=browser+('-aot' if strict else '-interpreter')
                checks=[('full',['tools/test_web.py',*common,'--sdl-interop','--native-runner',str(ROOT/'build/desktop/bin/dasSkia_runner.exe')]),
                        ('lifecycle',['tools/test_web_lifecycle.py',*common,'--sdl-interop']),
                        ('texture',['tools/test_web_sdl_texture.py',*common])]
                for name,args in checks:
                    logfile=LOGS/('browser-'+tag+'-'+name+'.log')
                    with logfile.open('w',encoding='utf-8') as log:
                        proc=subprocess.run([sys.executable,'-u',*args],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
                    results.append({'profile':tag,'check':name,'exit_code':proc.returncode,'log':str(logfile.relative_to(ROOT))})
                    print(tag,name,'exit',proc.returncode,flush=True)
                    if proc.returncode:print(logfile.read_text(errors='replace')[-12000:],flush=True)
    finally:
        for server in servers:server.shutdown();server.server_close()
        (LOGS/'browser-results.json').write_text(json.dumps(results,indent=2)+'\n')
    if len(results)!=12 or any(r['exit_code'] for r in results):raise SystemExit(1)
if __name__=='__main__':main()
