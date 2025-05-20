import Foundation
import BigDecimal
import BigInt

public enum KDLTokenizerContext {
    case ident
    case keyword
    case string
    case rawstring
    case multiLineString
    case multiLineRawstring
    case binary
    case octal
    case hexadecimal
    case decimal
    case singleLineComment
    case multiLineComment
    case whitespace
    case equals
}

public enum KDLToken: Equatable, Sendable {
    case IDENT(String)
    case STRING(String)
    case RAWSTRING(String)
    case INTEGER(Int)
    case BIGINT(BInt)
    case FLOAT(Float)
    case DECIMAL(BigDecimal)
    case TRUE
    case FALSE
    case NULL
    case WS
    case NEWLINE
    case LBRACE
    case RBRACE
    case LPAREN
    case RPAREN
    case EQUALS
    case SEMICOLON
    case EOF
    case SLASHDASH
    case NONE
}

internal func charRange(from: Int, to: Int) -> [Character] {
    return (from...to).map { Character(UnicodeScalar($0)!) }
}

internal func concat<T>(_ arrays: [T]...) -> [T] {
    return arrays.reduce([], { a, b in a + b })
}

public class KDLTokenizer {
    static let WHITESPACE: [Character] = [
        "\u{0009}", "\u{0020}", "\u{00A0}", "\u{1680}",
        "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}",
        "\u{2004}", "\u{2005}", "\u{2006}", "\u{2007}",
        "\u{2008}", "\u{2009}", "\u{200A}", "\u{202F}",
        "\u{205F}", "\u{3000}" 
    ]
    static let WS = "[\(WHITESPACE.map{"\($0)"}.joined(separator: ""))]"

    static let SYMBOLS: [Character : KDLToken] = [
        "{": KDLToken.LBRACE,
        "}": KDLToken.RBRACE,
        ";": KDLToken.SEMICOLON,
        "=": KDLToken.EQUALS
    ]


    static let NEWLINES: [Character] = ["\u{000A}", "\u{0085}", "\u{000B}", "\u{000C}", "\u{2028}", "\u{2029}", "\r\n", "\r"]
    static let NEWLINES_PATTERN = "\(NEWLINES.map{"\($0)"}.joined(separator: "|"))|\\r\\n?"

    static let DIGITS: [Character] = (0...9).map { let s = "\($0)"; return s[s.startIndex] }

    static let NON_IDENTIFIER_CHARS: [Character?] =
        [nil] +
        concat(
            WHITESPACE,
            NEWLINES,
            Array(SYMBOLS.keys),
            ["\r", "\\", "[", "]", "(", ")", "\"", "/", "#"],
            charRange(from: 0x0000, to: 0x0020)
        )
    static let NON_INITIAL_IDENTIFIER_CHARS: [Character?] = concat(
        NON_IDENTIFIER_CHARS,
        DIGITS
    )

    static let FORBIDDEN: [Character] = concat(
        charRange(from: 0x0000, to: 0x0008),
        charRange(from: 0x000E, to: 0x001F),
        ["\u{007F}"],
        charRange(from: 0x200E, to: 0x200F),
        charRange(from: 0x202A, to: 0x202E),
        charRange(from: 0x2066, to: 0x2069),
        ["\u{FEFF}"]
    )

    static let VERSION_PATTERN = "\\/-\(WS)*kdl-version\(WS)+(\\d+)\(WS)*\(NEWLINES_PATTERN)"

    enum TokenizationError : Error {
        case unexpectedCharacter(Character)
        case unexpectedNullContext
        case unexpectedEOF
        case unknownKeyword(String)
        case identifierLiteral(String)
        case identifierIllegalFloat(String)
        case unterminatedString
        case unterminatedRawstring
        case forbiddenCharacter(Character)
        case invalidDecimal(String)
        case invalidHexadecimal(String)
        case invalidOctal(String)
        case invalidBinary(String)
        case unexpectedEscape(String)
        case invalidUnicodeEscape(String)
        case invalidCodePoint(Int)
        case invalidMultilineFinalLine
        case invalidMultilineIndentation
    }

    var str: String = ""
    var index: Int
    var start: Int
    var previousContext: KDLTokenizerContext? = nil
    var context: KDLTokenizerContext? = nil {
        didSet {
            self.previousContext = oldValue
        }
    }
    var rawstringHashes: Int = -1
    var buffer: String = ""
    var done: Bool = false
    var commentNesting: Int = 0
    var peekedTokens: [KDLToken] = []
    var inType: Bool = false
    var lastToken: KDLToken? = nil
    var line = 1
    var column = 1
    var lineAtStart = 1
    var columnAtStart = 1

    init(_ s: String, start: Int = 0) {
        self.str = s
        if str.starts(with: "\u{FEFF}") {
            str.remove(at: str.startIndex)
        }
        self.index = start
        self.start = start
    }

    public func versionDirective() throws -> UInt? {
        if let match = try Regex(KDLTokenizer.VERSION_PATTERN).prefixMatch(in: str) {
            if let version = match.output[1].substring {
                return UInt(version)
            }
        }
        return nil
    }

    public func reset() {
        self.index = self.start
    }

    public func peekToken() throws -> KDLToken {
        if peekedTokens.isEmpty {
            peekedTokens.append(try _nextToken())
        }
        return peekedTokens.first!
    }

    public func peekTokenAfterNext() throws -> KDLToken {
        if peekedTokens.isEmpty {
            peekedTokens.append(try _nextToken())
            peekedTokens.append(try _nextToken())
        } else if peekedTokens.count == 1 {
            peekedTokens.append(try _nextToken())
        }
        return peekedTokens[1]
    }

    public func nextToken() throws -> KDLToken {
        if !peekedTokens.isEmpty {
            return peekedTokens.removeFirst()
        } else {
            return try _nextToken()
        }
    }

    func _nextToken() throws -> KDLToken {
        let token = try _readNextToken()
        switch token {
            case .NONE: ()
            default: self.lastToken = token
        }
        return token
    }

    func _readNextToken() throws -> KDLToken {
        self.context = nil
        self.previousContext = nil
        self.lineAtStart = line
        self.columnAtStart = column
        while true {
            let c = try char(index)
            if context == nil {
                if c == nil {
                    if done {
                        return KDLToken.NONE
                    }
                    self.done = true
                    return KDLToken.EOF
                } else {
                    switch c! {
                    case "\"":
                        self.buffer = ""
                        if try char(index + 1) == "\"" && char(index + 2) == "\"" {
                            let c2 = try char(index + 3)
                            if c2 != nil && KDLTokenizer.NEWLINES.contains(c2!) {
                                self.context = .multiLineString
                                try _traverse(4)
                            } else {
                                throw TokenizationError.unexpectedCharacter(c2!)
                            }
                        } else {
                            self.context = .string
                            try _traverse()
                        }
                    case "#":
                        if try char(index + 1) == "\"" {
                            self.buffer = ""
                            self.rawstringHashes = 1
                            if try char(index + 2) == "\"" && char(index + 3) == "\"" {
                                let c2 = try char(index + 4)
                                if c2 != nil && KDLTokenizer.NEWLINES.contains(c2!) {
                                    self.context = .multiLineRawstring
                                    try _traverse(5)
                                } else {
                                    throw TokenizationError.unexpectedCharacter(c2!)
                                }
                            } else {
                                self.context = .rawstring
                                try _traverse(2)
                            }
                            continue
                        } else if try char(index + 1) == "#" {
                            var i = index + 1
                            self.rawstringHashes = 1
                            while try char(i) == "#" {
                                self.rawstringHashes += 1
                                i += 1
                            }
                            if try char(i) == "\"" {
                                self.buffer = ""
                                if try char(i + 1) == "\"" && char(i + 2) == "\"" {
                                    let c2 = try char(i + 3)
                                    if c2 != nil && KDLTokenizer.NEWLINES.contains(c2!) {
                                        self.context = .multiLineRawstring
                                        try _traverse(rawstringHashes + 4)
                                    } else {
                                        throw TokenizationError.unexpectedCharacter(c2!)
                                    }
                                } else {
                                    self.context = .rawstring
                                    try _traverse(rawstringHashes + 1)
                                }
                                continue
                            }
                        }
                        self.context = .keyword
                        self.buffer = String(c!)
                        try _traverse()
                    case "-":
                        let n = try char(index + 1)
                        let n2 = try char(index + 2)
                        if n != nil && KDLTokenizer.DIGITS.contains(n!) {
                            if n == "0" && n2 != nil && ["b", "o", "x"].contains(n2) {
                                self.context = try _integerContext(n2!)
                                try _traverse(2)
                            } else {
                                self.context = .decimal
                            }
                        } else {
                            self.context = .ident
                        }
                        self.buffer = String(c!)
                        try _traverse()
                    case "0"..."9", "+":
                        let n = try char(index + 1)
                        let n2 = try char(index + 2)
                        if c == "0" && n != nil && ["b", "o", "x"].contains(n) {
                            self.buffer = ""
                            self.context = try _integerContext(n!)
                            try _traverse(2)
                        } else if c == "+" && n == "0" && n2 != nil && ["b", "o", "x"].contains(n2) {
                            self.buffer = String(c!)
                            self.context = try _integerContext(n2!)
                            try _traverse(3)
                        } else {
                            self.buffer = String(c!)
                            self.context = .decimal
                            try _traverse()
                        }
                    case "\\":
                        let t = KDLTokenizer(str, start: index + 1)
                        switch try t.nextToken() {
                        case .NEWLINE, .EOF:
                            self.context = .whitespace
                            try _traverseTo(t.index)
                            continue
                        case .WS:
                            self.buffer = String(c!)
                            switch try t.nextToken() {
                            case .NEWLINE, .EOF:
                                self.context = .whitespace
                                try _traverseTo(t.index)
                            default: throw TokenizationError.unexpectedCharacter(c!)
                            }
                        default: throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case "=":
                        self.context = .equals
                        try _traverse()
                    case _ where KDLTokenizer.SYMBOLS[c!] != nil: ()
                        try _traverse()
                        return KDLTokenizer.SYMBOLS[c!]!
                    case _ where KDLTokenizer.NEWLINES.contains(c!):
                        try _traverse()
                        return .NEWLINE
                    case "/":
                        switch try char(index + 1) {
                        case "/":
                            if inType || lastToken == .RPAREN {
                                throw TokenizationError.unexpectedCharacter(c!)
                            }
                            self.context = .singleLineComment
                            try _traverse(2)
                        case "*":
                            self.commentNesting = 1
                            self.context = .multiLineComment
                            try _traverse(2)
                        case "-":
                            try _traverse(2)
                            return .SLASHDASH
                        default: throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case _ where KDLTokenizer.WHITESPACE.contains(c!):
                        self.context = .whitespace
                        try _traverse()
                    case _ where !KDLTokenizer.NON_INITIAL_IDENTIFIER_CHARS.contains(c):
                        self.context = .ident
                        self.buffer = String(c!)
                        try _traverse()
                    case "(":
                        self.inType = true
                        try _traverse()
                        return .LPAREN
                    case ")":
                        self.inType = false
                        try _traverse()
                        return .RPAREN
                    default:
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                }
            } else {
                switch context {
                    case .some(.ident):
                        if !KDLTokenizer.NON_IDENTIFIER_CHARS.contains(c) {
                            self.buffer += String(c!)
                            try _traverse()
                        } else {
                            if ["true", "false", "null", "inf", "-inf", "nan"].contains(buffer) {
                                throw TokenizationError.identifierLiteral(buffer)
                            }
                            if (buffer.starts(with: try Regex("^\\.\\d"))) {
                                throw TokenizationError.identifierIllegalFloat(buffer)
                            }

                            return .IDENT(buffer)
                        }
                    case .some(.keyword):
                        if try c != nil && String(c!).contains(Regex("[a-z\\-]")) {
                            self.buffer += String(c!)
                            try _traverse()
                        } else {
                            switch buffer {
                            case "#true": return .TRUE
                            case "#false": return .FALSE
                            case "#null": return .NULL
                            case "#inf": return .FLOAT(Float.infinity)
                            case "#-inf": return .FLOAT(-Float.infinity)
                            case "#nan": return .FLOAT(Float.nan)
                            default: throw TokenizationError.unknownKeyword(buffer)
                            }
                        }
                    case .some(.string):
                        switch c {
                        case "\\":
                            self.buffer += String(c!)
                            var c2 = try char(index + 1)
                            self.buffer += String(c2!)
                            if KDLTokenizer.NEWLINES.contains(c2!) {
                                var i = 2
                                c2 = try char(index + i)
                                while KDLTokenizer.NEWLINES.contains(c2!) {
                                    self.buffer += String(c2!)
                                    i += 1
                                    c2 = try char(index + i)
                                }
                                try _traverse(i)
                            } else {
                                try _traverse(2)
                            }
                        case "\"":
                            try _traverse()
                            return .STRING(try _unescape(buffer))
                        case nil:
                            throw TokenizationError.unterminatedString
                        default:
                            if KDLTokenizer.NEWLINES.contains(c!) {
                                throw TokenizationError.unexpectedCharacter(c!)
                            }
                            self.buffer += String(c!)
                            try _traverse()
                        }
                    case .some(.multiLineString):
                        switch c {
                        case "\\":
                            self.buffer += String(c!)
                            self.buffer += String(try char(index + 1)!)
                            try _traverse(2)
                        case "\"":
                            if try char(index + 1) == "\"" && char(index + 2) == "\"" {
                                try _traverse(3)
                                return .STRING(try _unescapeNonWs(_dedent(_unescapeWs(buffer, skipBs: true))))
                            }
                            self.buffer += String(c!)
                            try _traverse()
                        case nil:
                            throw TokenizationError.unterminatedString
                        default:
                            self.buffer += String(c!)
                            try _traverse()
                        }
                    case .some(.rawstring):
                        if c == nil {
                            throw TokenizationError.unterminatedRawstring
                        }

                        if c == "\"" {
                            var h = 0
                            while try char(index + 1 + h) == "#" && h < rawstringHashes {
                                h += 1
                            }
                            if h == self.rawstringHashes {
                                try _traverse(1 + h)
                                return .RAWSTRING(buffer)
                            }
                        } else if KDLTokenizer.NEWLINES.contains(c!) {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }

                        self.buffer += String(c!)
                        try _traverse()
                    case .some(.multiLineRawstring):
                        if c == nil {
                            throw TokenizationError.unterminatedRawstring
                        }

                        if try c == "\"" &&
                            char(index + 1) == "\"" &&
                            char(index + 2) == "\"" &&
                            char(index + 3) == "#" {
                                var h = 1
                                while try char(index + 3 + h) == "#" && h < rawstringHashes {
                                    h += 1
                                }
                                if h == rawstringHashes {
                                    try _traverse(3 + h)
                                    return .RAWSTRING(try _dedent(buffer))
                                }
                        }

                        self.buffer += String(c!)
                        try _traverse()
                    case .some(.decimal):
                        if try c != nil && String(c!).contains(Regex("[0-9.\\-+_eE]")) {
                            self.buffer += String(c!)
                            try _traverse()
                        } else if c == nil || KDLTokenizer.WHITESPACE.contains(c!) || KDLTokenizer.NEWLINES.contains(c!) {
                            return try _parseDecimal(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.hexadecimal):
                        if try c != nil && String(c!).contains(Regex("[0-9a-fA-F_]")) {
                            self.buffer += String(c!)
                            try _traverse()
                        } else if c == nil || KDLTokenizer.WHITESPACE.contains(c!) || KDLTokenizer.NEWLINES.contains(c!) {
                            return try _parseHexadecimal(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.octal):
                        if try c != nil && String(c!).contains(Regex("[0-7_]")) {
                            self.buffer += String(c!)
                            try _traverse()
                        } else if c == nil || KDLTokenizer.WHITESPACE.contains(c!) || KDLTokenizer.NEWLINES.contains(c!) {
                            return try _parseOctal(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.binary):
                        if try c != nil && String(c!).contains(Regex("[01_]")) {
                            self.buffer += String(c!)
                            try _traverse()
                        } else if c == nil || KDLTokenizer.WHITESPACE.contains(c!) || KDLTokenizer.NEWLINES.contains(c!) {
                            return try _parseBinary(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.singleLineComment):
                        if c == nil {
                            self.done = true
                            return .EOF
                        } else if KDLTokenizer.NEWLINES.contains(c!) || c == "\r" {
                            self.context = nil
                            self.columnAtStart = column
                            continue
                        } else {
                            try _traverse()
                        }
                    case .some(.multiLineComment):
                        switch (c, try char(index + 1)) {
                        case ("/", "*"):
                            self.commentNesting += 1
                            try _traverse(2)
                        case ("*", "/"):
                            self.commentNesting -= 1
                            try _traverse(2)
                            if commentNesting == 0 {
                                _revertContext()
                            }
                        default:
                            try _traverse()
                        }
                    case .some(.whitespace):
                        if c != nil && KDLTokenizer.WHITESPACE.contains(c!) {
                            try _traverse()
                        } else if c == "=" {
                            self.context = .equals
                            try _traverse()
                        } else if c == "\\" {
                            let t = KDLTokenizer(str, start: index + 1)
                            switch try t.nextToken() {
                            case .NEWLINE, .EOF:
                                try _traverseTo(t.index)
                            case .WS:
                                switch try t.nextToken() {
                                case .NEWLINE, .EOF:
                                    try _traverseTo(t.index)
                                default: throw TokenizationError.unexpectedCharacter(c!)
                                }
                            default: throw TokenizationError.unexpectedCharacter(c!)
                            }
                        } else if try c == "/" && char(index + 1) == "*" {
                            self.commentNesting = 1
                            self.context = .multiLineComment
                            try _traverse(2)
                        } else {
                            return .WS
                        }
                    case .some(.equals):
                        let t = KDLTokenizer(str, start: index)
                        if try t.nextToken() == .WS {
                            try _traverseTo(t.index)
                        }
                        return .EQUALS
                    case .none: throw TokenizationError.unexpectedNullContext
                }
            }
        }
    }

    func char(_ i: Int) throws -> Character? {
        if i < 0 || i >= str.count {
            return nil
        }
        let c = str[str.index(str.startIndex, offsetBy: i)]
        if KDLTokenizer.FORBIDDEN.contains(c) {
            throw TokenizationError.forbiddenCharacter(c)
        }
        return c
    }

    func _traverse(_ n: Int = 1) throws {
        for i in 0..<n {
            let c = try char(index + i)
            if c == "\r" {
                column = 1
            } else if KDLTokenizer.NEWLINES.contains(c!) {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        index += n
    }

    func _traverseTo(_ i: Int) throws {
        try _traverse(i - index)
    }

    func _revertContext() {
        self.context = previousContext
        self.previousContext = nil
    }

    func _integerContext(_ n: Character) throws -> KDLTokenizerContext {
        switch n {
            case "b": return .binary
            case "o": return .octal
            case "x": return .hexadecimal
            default: throw TokenizationError.unexpectedCharacter(n)
        }
    }

    func _parseDecimal(_ s: String) throws -> KDLToken {
        if s.contains(try Regex("[.eE]")) {
            if try _checkFloat(s) {
                return .DECIMAL(BigDecimal(_munchUnderscores(s)))
            }
        }
        if try _checkInt(s) {
            let s = _munchUnderscores(s)
            if let i = Int(s) {
                return .INTEGER(i)
            }
            if let i = BInt(s) {
                return .BIGINT(i)
            }
        }
        if KDLTokenizer.NON_INITIAL_IDENTIFIER_CHARS.contains(s.first) ||
        s[s.index(s.startIndex, offsetBy: 1)...]
            .contains(where: { KDLTokenizer.NON_IDENTIFIER_CHARS.contains($0) }) {
                throw TokenizationError.invalidDecimal(s)
        }
        return .IDENT(s)
    }

    func _checkFloat(_ s: String) throws -> Bool {
        return s.contains(try Regex(#"^[+-]?[0-9][0-9_]*(\.[0-9][0-9_]*)?([eE][+-]?[0-9][0-9_]*)?$"#))
    }

    func _checkInt(_ s: String) throws -> Bool {
        return s.contains(try Regex(#"^[+-]?[0-9][0-9_]*$"#))
    }

    func _parseHexadecimal(_ s: String) throws -> KDLToken {
        if try !s.contains(Regex(#"^[+-]?[0-9a-fA-F][0-9a-fA-F_]*$"#)) {
            throw TokenizationError.invalidHexadecimal(s)
        }
        let s = _munchUnderscores(s)
        if let i = Int(s, radix: 16) {
            return .INTEGER(i)
        }
        if let i = BInt(s, radix: 16) {
            return .BIGINT(i)
        }
        throw TokenizationError.invalidHexadecimal(s)
    }

    func _parseOctal(_ s: String) throws -> KDLToken {
        if try !s.contains(Regex(#"^[+-]?[0-7][0-7_]*$"#)) {
            throw TokenizationError.invalidOctal(s)
        }
        let s = _munchUnderscores(s)
        if let i = Int(s, radix: 8) {
            return .INTEGER(i)
        }
        if let i = BInt(s, radix: 8) {
            return .BIGINT(i)
        }
        throw TokenizationError.invalidOctal(s)
    }

    func _parseBinary(_ s: String) throws -> KDLToken {
        if try !s.contains(Regex(#"^[+-]?[01][01_]*$"#)) {
            throw TokenizationError.invalidBinary(s)
        }
        let s = _munchUnderscores(s)
        if let i = Int(s, radix: 2) {
            return .INTEGER(i)
        }
        if let i = BInt(s, radix: 2) {
            return .BIGINT(i)
        }
        throw TokenizationError.invalidBinary(s)
    }

    func _munchUnderscores(_ s: String) -> String {
        return s.replacing("_", with: "")
    }

    func _unescapeWs(_ string: String, skipBs: Bool) -> String {
        return StringUnescaper(string).unescapeWs(skipBs: skipBs)
    }

    func _unescapeNonWs(_ string: String) throws -> String {
        return try StringUnescaper(string).unescapeNonWs()
    }

    func _unescape(_ string: String) throws -> String {
        return try _unescapeNonWs(_unescapeWs(string, skipBs: true))
    }

    func _dedent(_ string: String) throws -> String {
        return try StringUnescaper(string).dedent()
    }
}
