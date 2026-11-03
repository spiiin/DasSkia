#include "skia_sdl.h"
#include <SDL3/SDL_opengl.h>
#include <cstdlib>
#include <iostream>
#include <string>
int main() {
    std::unique_ptr<SkiaWindow> window(Skia_NewWindow("CI GL backend",32,32,true));
    if(!window) {std::cerr << "FAIL GL backend: " << skia_sdl_error << "\n";return 1;}
    auto renderer=reinterpret_cast<const char*>(glGetString(GL_RENDERER));
    auto version=reinterpret_cast<const char*>(glGetString(GL_VERSION));
    if(!renderer || !version) {std::cerr << "FAIL GL backend strings\n";return 2;}
    const char* require=std::getenv("DASSKIA_REQUIRE_SOFTWARE_GL");
    if(require && std::string(require)=="1" && std::string(renderer).find("llvmpipe")==std::string::npos) {
        std::cerr << "FAIL expected llvmpipe, got " << renderer << "\n";return 3;
    }
    std::cout << "PASS GL backend: " << renderer << "; " << version << "\n";
    return 0;
}
