#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include "skia_web_lifecycle.h"
EM_JS_DEPS(skia_lifecycle, "$GL");
// Reference counted DOM listeners coexist with host handlers and other targets.
EM_JS(int, Skia_WebObserveImpl, (int handle, int delta), {
    var ctx = GL.contexts[handle]?.GLctx;
    if (!ctx) return 0;
    var record = ctx.__dasSkiaLifecycle;
    if (delta > 0) {
        if (!record) {
            record = {refs:0, generation:0};
            record.lost = function(event) { event.preventDefault(); record.generation++; };
            ctx.canvas.addEventListener('webglcontextlost', record.lost);
            ctx.__dasSkiaLifecycle = record;
        }
        record.refs++;
    } else if (record && --record.refs === 0) {
        ctx.canvas.removeEventListener('webglcontextlost', record.lost);
        delete ctx.__dasSkiaLifecycle;
    }
    return 1;
});
EM_JS(int, Skia_WebContextStateImpl, (int handle), {
    var ctx = GL.contexts[handle]?.GLctx;
    if (!ctx || ctx.isContextLost()) return -1;
    return ctx.__dasSkiaLifecycle?.generation || 0;
});
extern "C" int Skia_WebObserve(int handle,int delta) {return Skia_WebObserveImpl(handle,delta);}
extern "C" int Skia_WebContextState(int handle) {return Skia_WebContextStateImpl(handle);}
#endif
