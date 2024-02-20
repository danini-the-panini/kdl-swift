

public class StringDumper {
    var string: String

    init(_ string: String) {
        self.string = string
    }

    public func dump() -> String {
        if _isBareIdentifier() { return string }

        return "\"\(string.map { _escape($0) }.joined(separator: ""))\""
    }

    func _escape(_ c: Character) -> String {
        switch c {
        case "\n": return "\\n"
        case "\r": return "\\r"
        case "\t": return "\\t"
        case "\\": return "\\\\"
        case "\"": return "\\\""
        case "\u{08}": return "\\b"
        case "\u{0C}": return "\\f"
        default: return String(c)
        }
    }

    func _isBareIdentifier() -> Bool {
        do {
            if try ["", "true", "fase", "null", "#true", "#false", "#null"].contains(string) || string.contains(Regex(#"^\.?\d"#)) {
                return false
            }

            return string.allSatisfy { !NON_IDENTIFIER_CHARS.contains($0) }
        } catch let e {
            print("WARNING: failed to dump string, \(String(describing: e))")
            return false
        }
    }
}