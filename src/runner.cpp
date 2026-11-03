#include "daScript/daScript.h"
#include "daScript/misc/sysos.h"
#include <iostream>
#include <memory>
#include <string>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif
DECLARE_MODULE(Module_dasSkia);
#ifdef DASSKIA_WITH_DASSDL3
DECLARE_MODULE(Module_dasSDL3);
DECLARE_MODULE(Module_skiaSDL3);
#endif
using namespace das;
struct Script {
    TextPrinter out;
    ModuleGroup modules;
    ProgramPtr program;
    std::unique_ptr<Context> context;
    SimFunction* frame=nullptr;
    SimFunction* quit=nullptr;
    bool stopped=false;
    bool smoke=false,frameAotLogged=false;
    int frameCount=0;
    int result=0;
    bool load(const char* path) {
        auto access=make_smart<FsFileAccess>();
#ifdef __EMSCRIPTEN__
        access->addFsRoot("dasskia","/dasskia");
#else
        access->addFsRoot("dasskia",std::string(DASSKIA_ROOT)+"/dasskia");
#endif
#ifdef DASSKIA_WITH_DASSDL3
#ifdef __EMSCRIPTEN__
        access->addFsRoot("dassdl3","/dassdl3");
#else
        access->addFsRoot("dassdl3",std::string(DASSKIA_DASSDL3_ROOT)+"/dassdl3");
#endif
#endif
        CodeOfPolicies policy;
#ifdef DASSKIA_STRICT_AOT
        policy.aot=true; policy.fail_on_no_aot=true; policy.tune_frozen=true;
#endif
        program=compileDaScript(path,access,out,modules,policy);
        auto errors=[&] { for(auto& e:program->errors) out << reportError(e.at,e.what,e.extra,e.fixme,e.cerr); };
        if(program->failed()) { errors(); return false; }
        context=std::make_unique<Context>(program->getContextStackSize());
        if(!program->simulate(*context,out)) { errors(); return false; }
        frame=context->findFunction("app_frame"); quit=context->findFunction("app_quit");
        return true;
    }
    int call(const char* name) {
        auto fn=context->findFunction(name);
        if(!fn || !verifyCall<int32_t>(fn->debugInfo,modules)) { out << "Expected [export] def " << name << "() : int\n"; return 1; }
#ifdef DASSKIA_STRICT_AOT
        if(!fn->aot) { out << "Missing AOT entry: " << name << "\n"; return 1; }
        if(std::string(name)!="app_frame" || !frameAotLogged) out << name << " AOT=yes; fallback disabled\n";
        if(std::string(name)=="app_frame") frameAotLogged=true;
#endif
        auto value=context->evalWithCatch(fn,nullptr);
        if(auto e=context->getException()) { out << e << "\n"; return 1; }
        return cast<int32_t>::to(value);
    }
    void finish() {
        if(stopped) return; stopped=true;
        if(quit && verifyCall<void>(quit->debugInfo,modules)) {
#ifdef DASSKIA_STRICT_AOT
            if(!quit->aot) { out << "Missing AOT entry: app_quit\n"; result=1; return; }
            out << "app_quit AOT=yes; fallback disabled\n";
#endif
            context->evalWithCatch(quit,nullptr);
            if(auto e=context->getException()) { out << e << "\n"; result=1; }
        }
    }
};
#ifdef __EMSCRIPTEN__
static std::unique_ptr<Script> active;
static void tick() {
    int status=active->call("app_frame");
    if(status==0 && active->smoke && ++active->frameCount>=3) status=1;
    if(status!=0) { active->result=status<0?1:0; active->finish(); emscripten_cancel_main_loop(); }
}
#endif
int main(int argc,char** argv) {
#ifdef __EMSCRIPTEN__
    setDasRoot("/");
#else
    setDasRoot(DASSKIA_DAS_ROOT);
#endif
    NEED_ALL_DEFAULT_MODULES; NEED_MODULE(Module_dasSkia);
#ifdef DASSKIA_WITH_DASSDL3
    NEED_MODULE(Module_dasSDL3); NEED_MODULE(Module_skiaSDL3);
#endif
    Module::Initialize();
    int result=1;
    {
        auto script=std::make_unique<Script>();
#ifdef DASSKIA_STRICT_AOT
        std::cout << "STRICT_AOT=1; fallback disabled\n";
#endif
        script->smoke=argc>2 && std::string(argv[2])=="--smoke-test";
#ifdef __EMSCRIPTEN__
        const char* path=argc>1?argv[1]:"/examples/window.das";
#else
        if(argc<2) { std::cerr << "Usage: dasSkia_runner script.das\n"; return 2; }
        const char* path=argv[1];
#endif
        if(script->load(path)) {
            if(script->frame) {
                if(script->call("app_init")==0) {
#ifdef __EMSCRIPTEN__
                    active=std::move(script); emscripten_set_main_loop(tick,0,0); return 0;
#else
                    int status=0,frames=0;
                    const bool smoke=argc>2 && std::string(argv[2])=="--smoke-test";
                    while((status=script->call("app_frame"))==0) { if(smoke && ++frames>=3) { status=1; break; } }
                    script->result=status<0?1:0;
#endif
                } else script->result=1;
                script->finish(); result=script->result;
            } else result=script->call("main");
        }
    }
    Module::Shutdown(); return result;
}
