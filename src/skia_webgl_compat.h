#pragma once
// Skia m138's WebGL function table expects split 32-bit timeout arguments;
// Emscripten 5's public WebGL entry points take uint64_t. Adapt only this
// boundary, without modifying Skia or the SDK. Keep the function table ABI.
#ifdef __EMSCRIPTEN__
#include <webgl/webgl2.h>
static inline GLenum skia_webgl_client_wait(GLsync sync,GLbitfield flags,GLint lo,GLint hi) {
    GLuint64 timeout=((GLuint64)(GLuint)hi<<32)|(GLuint)lo;
    return emscripten_glClientWaitSync(sync,flags,timeout);
}
static inline void skia_webgl_wait(GLsync sync,GLbitfield flags,GLuint lo,GLuint hi) {
    emscripten_glWaitSync(sync,flags,((GLuint64)hi<<32)|lo);
}
#define emscripten_glClientWaitSync skia_webgl_client_wait
#define emscripten_glWaitSync skia_webgl_wait
#endif
