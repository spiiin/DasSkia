options gen2
require ./aot_unlinked
[export]
def main() : int {
    let value=required_value(6)
    print("FAIL IMPORT FALLBACK EXECUTED: {value}\n")
    return 0
}
