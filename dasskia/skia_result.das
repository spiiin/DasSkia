// Scope/Result pattern adapted from spiiin/dasSDL3.
options gen2
options rtti // SkiaResult typemacro uses ast_typedecl, including standalone AOT.
module skia_result shared public
require skia public
require daslib/result public
require daslib/typemacro_boost


struct SkiaError {
    operation : string
    message : string
}
// Unit carries no success flag: that belongs to the standard Result container.
// One storage byte keeps Option<Unit> layout identical in interpreter and C++ AOT.
// This is padding, not an additional success flag.
struct SkiaUnit {
    _storage : uint8
}

// Public spellings of the standard Result; no additional storage or ownership.
typedef public SkiaStatus = $Result<SkiaUnit; SkiaError>

[typemacro_function]
def public SkiaResult(macroArgument, passArgument : TypeDeclPtr; T : TypeDeclPtr) : TypeDeclPtr {
    // Start with the canonical Result layout, replacing only its value type.
    var resultType <- typeinfo ast_typedecl(type<$Result<int; SkiaError>>)
    resultType.argTypes[1] = clone_type(T)
    return <- resultType
}

def public skia_ok() : SkiaStatus { return ok(SkiaUnit(), type<SkiaError>) }
def public skia_error(operation, message : string) : SkiaError {
    return SkiaError(operation=operation, message=message)
}
