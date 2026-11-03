#pragma once
namespace das {
inline void registerGeometry(Module& module,ModuleLibrary& lib) {
    module.addAnnotation(new DummyTypeAnnotation("SkPathMeasure","SkPathMeasure",sizeof(SkPathMeasure),alignof(SkPathMeasure)));
    module.addAnnotation(new DummyTypeAnnotation("SkOpBuilder","SkOpBuilder",sizeof(SkOpBuilder),alignof(SkOpBuilder)));
    auto e=new Enumeration("SkPathOp"); e->external=true; e->cppName="SkPathOp"; e->baseType=Type::tInt;
#define VALUE(name,native) e->addIEx(#name,#native,int64_t(native),LineInfo());
    VALUE(Difference,kDifference_SkPathOp) VALUE(Intersect,kIntersect_SkPathOp) VALUE(Union,kUnion_SkPathOp)
    VALUE(Xor,kXOR_SkPathOp) VALUE(ReverseDifference,kReverseDifference_SkPathOp)
#undef VALUE
    module.addEnumeration(e);
#define BIND(F) addExtern<DAS_BIND_FUN(F)>(module,lib,#F,SideEffects::worstDefault,#F)
    BIND(Skia_PathOp);
    BIND(Skia_PathSimplify);
    BIND(Skia_PathAsWinding);
    BIND(Skia_PathIsFinite);
    BIND(Skia_PathFromSvg);
    BIND(Skia_PathToSvg);
    BIND(Skia_PathFillWithPaint);
    BIND(Skia_NewPathMeasure);
    BIND(Skia_DeletePathMeasure);
    BIND(Skia_PathMeasureSetPath);
    BIND(Skia_PathMeasureLength);
    BIND(Skia_PathMeasureIsClosed);
    BIND(Skia_PathMeasureNext);
    BIND(Skia_PathMeasurePosTan);
    BIND(Skia_PathMeasureMatrix);
    BIND(Skia_PathMeasureSegment);
    BIND(Skia_NewPathBuilder);
    BIND(Skia_DeletePathBuilder);
    BIND(Skia_PathBuilderAdd);
    BIND(Skia_PathBuilderResolve);
#undef BIND
}
}
