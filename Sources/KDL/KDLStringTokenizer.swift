public class KDLStringTokenizer {
    var str: String

    init(_ str: String) {
        self.str = str
    }

    public func process() throws -> String {
        var i = 0
        var buffer = ""
        while i < str.count {
            let c = char(i)
            switch c {
            case .none: return buffer
            case .some("\\"):
                switch char(i+1) {
                    case .none: return buffer
                    case .some("n"): buffer += "\n"; i += 1
                    case .some("r"): buffer += "\r"; i += 1
                    case .some("t"): buffer += "\t"; i += 1
                    case .some("\\"): buffer += "\\"; i += 1
                    case .some("\""): buffer += "\""; i += 1
                    case .some("b"): buffer += "\u{08}"; i += 1
                    case .some("f"): buffer += "\u{0C}"; i += 1
                    case .some("s"): buffer += " "; i += 1
                    case .some("u"):
                        switch char(i+2) {
                            case .some("{"):
                                var hex = ""
                                var j = i+3
                                while let c = char(j), _isHex(c) {
                                    hex += String(c)
                                    j += 1
                                }
                                if hex.count > 6 || char(j) != "}" {
                                    throw KDLTokenizer.TokenizationError.invalidUnicodeEscape(hex)
                                }
                                if let code = Int(hex, radix: 16) {
                                    if code < 0 || code > 0x10FFFF {
                                        throw KDLTokenizer.TokenizationError.invalidCodePoint(code)
                                    }
                                    i = j
                                    if let s = UnicodeScalar(code) {
                                        buffer += String(Character(s))
                                    }
                                } else {
                                    throw KDLTokenizer.TokenizationError.invalidUnicodeEscape(hex)
                                }
                            default: throw KDLTokenizer.TokenizationError.invalidUnicodeEscape("")
                        }
                    case .some(let c):
                        if WHITESPACE.contains(c) || NEWLINES.contains(c) {
                            var j = i+2
                            while let c = char(j), WHITESPACE.contains(c) || NEWLINES.contains(c) {
                                j += 1
                            }
                            i = j-1
                        } else {
                            throw KDLTokenizer.TokenizationError.unexpectedEscape("\\\(c)")
                        }
                }
            case .some(let c): buffer += String(c)
            }
            i += 1
        }
        return buffer
    }

    func char(_ i: Int) -> Character? {
        if i < 0 || i >= str.count {
            return nil
        }
        return str[str.index(str.startIndex, offsetBy: i)]
    }

    func _isHex(_ c: Character) -> Bool {
        switch c.lowercased() {
        case "a", "b", "c", "d", "e", "f", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9": return true
        default: return false
        }
    }
}