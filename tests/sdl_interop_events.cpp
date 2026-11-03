// Reuse the actual host lifecycle, including exception and shutdown handling.
#define main SkiaExampleRunnerMain
#include "../src/runner.cpp"
#undef main
#include <SDL3/SDL.h>

int main() {
    setDasRoot(DASSKIA_DAS_ROOT);
    NEED_ALL_DEFAULT_MODULES; NEED_MODULE(Module_dasSkia);
    NEED_MODULE(Module_dasSDL3); NEED_MODULE(Module_skiaSDL3);
    Module::Initialize();
    int result=0;
    for (auto kind : {SDL_EVENT_WINDOW_CLOSE_REQUESTED,SDL_EVENT_KEY_DOWN,SDL_EVENT_QUIT}) {
        Script script;
        if (!script.load(DASSKIA_ROOT "/examples/sdl_interop.das") || script.call("app_init")!=0) {
            script.finish(); result=1; break;
        }
        int count=0;
        auto windows=SDL_GetWindows(&count);
        if (!windows || count!=1) {
            SDL_free(windows);script.finish();result=2;break;
        }
        auto id=SDL_GetWindowID(windows[0]);
        SDL_HideWindow(windows[0]);SDL_free(windows);
        // A close request for another window must leave this example running.
        SDL_Event wrong{};wrong.type=SDL_EVENT_WINDOW_CLOSE_REQUESTED;wrong.window.windowID=id+1000;
        if (!SDL_PushEvent(&wrong) || script.call("app_frame")!=0) {
            script.finish();result=3;break;
        }
        SDL_Event event{};event.type=kind;
        if (kind==SDL_EVENT_WINDOW_CLOSE_REQUESTED) event.window.windowID=id;
        if (kind==SDL_EVENT_KEY_DOWN) {event.key.windowID=id;event.key.key=SDLK_ESCAPE;}
        bool pushed=SDL_PushEvent(&event);
        int status=pushed?script.call("app_frame"):-1;
        script.finish();
        if (status!=1 || script.result!=0 || SDL_WasInit(SDL_INIT_VIDEO)!=0) {result=4;break;}
        std::cout << "PASS interop event " << uint32_t(kind) << "; app_quit released SDL\n";
    }
    Module::Shutdown();
    return result;
}
