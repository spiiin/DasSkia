#pragma once
namespace das {
inline void registerPicture(Module& module,ModuleLibrary& lib) {
    module.addAnnotation(new DummyTypeAnnotation("SkPictureRecorder","SkPictureRecorder",sizeof(SkPictureRecorder),alignof(SkPictureRecorder)));
    module.addAnnotation(new DummyTypeAnnotation("SkPicture","SkPicture",sizeof(SkPicture),alignof(SkPicture)));
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_NewPictureRecorder);
    BIND(Skia_DeletePictureRecorder);
    BIND(Skia_BeginPictureRecording);
    BIND(Skia_PictureRecordingCanvas);
    BIND(Skia_FinishPicture);
    BIND(Skia_FinishPictureWithCull);
    BIND(Skia_PictureUnref);
    BIND(Skia_PictureCull);
    BIND(Skia_PictureID);
    BIND(Skia_PictureOpCount);
    BIND(Skia_PictureBytes);
    BIND(Skia_DrawPicture);
    BIND(Skia_PlaybackPicture);
    BIND(Skia_SerializePicture);
    BIND(Skia_DeserializePicture);
    BIND(Skia_SavePicture);
    BIND(Skia_LoadPicture);
    BIND(Skia_PictureShader);
#undef BIND
}
}
