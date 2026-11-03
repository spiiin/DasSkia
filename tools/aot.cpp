#include "daScript/daScript.h"
#include <fstream>
DECLARE_MODULE(Module_dasSkia);
#ifdef DASSKIA_WITH_DASSDL3
DECLARE_MODULE(Module_dasSDL3);
DECLARE_MODULE(Module_skiaSDL3);
#endif
using namespace das;
static int generate(const char* input,const char* output) {
    TextPrinter log;
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
    ModuleGroup scripts,compilers;
    CodeOfPolicies policy;
    policy.aot_module=true; policy.tune_frozen=true; policy.fail_on_lack_of_aot_export=true;
    auto script=compileDaScript(input,access,log,scripts,policy);
    auto compiler=compileDaScript(getDasRoot()+"/daslib/aot_cpp.das",access,log,compilers,policy);
    for(auto p:{script,compiler}) {
        if(p->failed()) {
            for(auto& e:p->errors) log << reportError(e.at,e.what,e.extra,e.fixme,e.cerr);
            return 1;
        }
    }
    Context sc(script->getContextStackSize()),cc(compiler->getContextStackSize());
    if(!script->simulate(sc,log) || !compiler->simulate(cc,log)) return 2;
    auto fn=cc.findFunction("run_aot"); if(!fn) return 3;
    vec4f args[]={cast<Program*>::from(script.get()),cast<Context*>::from(&sc),cast<CodeOfPolicies*>::from(&policy)};
    auto value=cc.evalWithCatch(fn,args);
    if(auto e=cc.getException()) { log << e << "\n"; return 4; }
    auto text=cast<char*>::to(value); if(!text || !*text) return 5;
    std::ofstream file(output,std::ios::binary); file<<text; return file?0:6;
}
int main(int argc,char** argv) {
    if(argc!=3) return 7;
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
    int status=generate(argv[1],argv[2]); Module::Shutdown(); return status;
}
