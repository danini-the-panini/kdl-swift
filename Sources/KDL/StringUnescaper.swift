public class StringUnescaper {
    var str: String

    init(_ str: String) {
        self.str = str
    }

    public func unescapeWs() -> String {
        var i = 0
        var buffer = ""
        while i < str.count {
            let c = char(i)
            switch c {
            case .none: return buffer
            case .some("\\"):
                let c2 = char(i+1)
                switch c2 {
                case .none: return buffer
                case .some(_)
                where
                    KDLTokenizer.WHITESPACE.contains(c2!) ||
                    KDLTokenizer.NEWLINES.contains(c2!):
                        i += 1
                        while let c3 = char(i),
                            KDLTokenizer.WHITESPACE.contains(c3) ||
                            KDLTokenizer.NEWLINES.contains(c3) {
                                i += 1
                        }
                case .some("\\"):
                    buffer += "\\"
                    i += 2
                default:
                    buffer += String(c!)
                    i += 1
                }
            default:
                buffer += String(c!)
                i += 1
            }
        }
        return buffer
    }

    public func unescapeNonWs() throws -> String {
        var i = 0
        var buffer = ""
        while i < str.count {
            let c = char(i)
            switch c {
            case .none: return buffer
            case .some("\\"):
                switch char(i+1) {
                    case .none: return buffer
                    case .some("\\"): buffer += "\\"
                    case .some("n"): buffer += "\n"; i += 1
                    case .some("r"): buffer += "\r"; i += 1
                    case .some("t"): buffer += "\t"; i += 1
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
                        throw KDLTokenizer.TokenizationError.unexpectedEscape("\\\(c)")
                }
            case .some(let c): buffer += String(c)
            }
            i += 1
        }
        return buffer
    }

    public func dedent() throws -> String {
        var lines = _lines()
        if lines.isEmpty {
            throw KDLTokenizer.TokenizationError.invalidMultilineFinalLine
        }
        let indent = lines.removeLast()

        if !indent.isEmpty {
            if indent.contains(where: { !KDLTokenizer.WHITESPACE.contains($0) }) {
                throw KDLTokenizer.TokenizationError.invalidMultilineFinalLine
            }
            if lines.contains(where: { !$0.starts(with: indent) }) {
                throw KDLTokenizer.TokenizationError.invalidMultilineIndentation
            }
        }

        return lines.map {
            $0.suffix(from: $0.index($0.startIndex, offsetBy: indent.count))
        }.joined(separator: "\n")
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

    func _lines() -> [String] {
        var lines: [String] = []
        var i = 0
        var buffer = ""
        while i < str.count {
            let c = char(i)
            switch c {
            case .none:
                lines.append(buffer)
                break
            case .some(_) where KDLTokenizer.NEWLINES.contains(c!):
                lines.append(buffer)
                buffer = ""
            case .some("\r"):
                let c2 = char(i)
                if c2 != nil && KDLTokenizer.NEWLINES.contains(c2!) {
                    lines.append(buffer)
                    i += 1
                } else {
                    lines.append(buffer)
                }
                buffer = ""
            default:
                buffer += String(c!)
            }
            i += 1
        }
        lines.append(buffer)
        return lines
    }
}
