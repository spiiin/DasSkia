#pragma once
#ifdef __EMSCRIPTEN__
extern "C" {
int Skia_WebObserve(int handle, int delta);
int Skia_WebContextState(int handle);
}
#endif
