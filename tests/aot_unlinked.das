options gen2
module aot_unlinked shared public
[never_inline]
def public required_value(value : int) : int {
    print("FAIL IMPORT FALLBACK EXECUTED\n")
    return value*7+1
}
