public class StringDumperV1: StringDumper {
    override func _isBareIdentifier() -> Bool {
        do {
            if try ["", "true", "false", "null"].contains(string) || string.contains(Regex(#"^\.?\d"#)) {
                return false
            }

            return string.allSatisfy { !KDLTokenizerV1._NON_IDENTIFIER_CHARS.contains($0) }
        } catch let e {
            print("WARNING: failed to dump string, \(String(describing: e))")
            return false
        }
    }
}
