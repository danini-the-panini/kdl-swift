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

public enum KDLToken: Equatable {
    case IDENT(String)
    case STRING(String)
    case RAWSTRING(String)
    case INTEGER(Int)
    case FLOAT(Float)
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

let EQUALS: [Character] = ["=", "﹦", "＝", "🟰"]

let SYMBOLS: [Character : KDLToken] = [
    "{": KDLToken.LBRACE,
    "}": KDLToken.RBRACE,
    ";": KDLToken.SEMICOLON,
]

public let WHITESPACE: [Character] = [
    "\u{0009}", "\u{000B}", "\u{0020}", "\u{00A0}",
    "\u{1680}", "\u{2000}", "\u{2001}", "\u{2002}",
    "\u{2003}", "\u{2004}", "\u{2005}", "\u{2006}",
    "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}",
    "\u{202F}", "\u{205F}", "\u{3000}" 
]

let NEWLINES: [Character] = ["\u{000A}", "\u{0085}", "\u{000C}", "\u{2028}", "\u{2029}", "\r\n", "\r"]

let DIGITS: [Character] = (0...9).map { let s = "\($0)"; return s[s.startIndex] }

let NON_IDENTIFIER_CHARS: [Character?] =
    [nil] +
    concat(
        WHITESPACE,
        NEWLINES,
        EQUALS,
        Array(SYMBOLS.keys),
        ["\r", "\\", "[", "]", "(", ")", "\"", "/", "#"],
        charRange(from: 0x0000, to: 0x0020)
    )
let NON_INITIAL_IDENTIFIER_CHARS: [Character?] = concat(
    NON_IDENTIFIER_CHARS,
    DIGITS
)

let FORBIDDEN: [Character] = concat(
    charRange(from: 0x0000, to: 0x0008),
    charRange(from: 0x000E, to: 0x001F),
    ["\u{007F}"],
    charRange(from: 0x200E, to: 0x200F),
    charRange(from: 0x202A, to: 0x202E),
    charRange(from: 0x2066, to: 0x2069),
    ["\u{FEFF}"]
)

public class KDLTokenizer {
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

    init(_ s: String, start: Int = 0) {
        self.str = s
        self.index = start
        self.start = start
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
                        if try char(index + 1) == "\n" {
                            self.context = .multiLineString
                            self.index += 2
                        } else {
                            self.context = .string
                            self.index += 1
                        }
                    case "#":
                        if try char(index + 1) == "\"" {
                            self.buffer = ""
                            self.rawstringHashes = 1
                            if try char(index + 2) == "\n" {
                                self.context = .multiLineRawstring
                                self.index += 3
                            } else {
                                self.context = .rawstring
                                self.index += 2
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
                                if try char(i + 1) == "\n" {
                                    self.context = .multiLineRawstring
                                    self.index = i + 2
                                } else {
                                    self.context = .rawstring
                                    self.index = i + 1
                                }
                                continue
                            }
                        }
                        self.context = .keyword
                        self.buffer = String(c!)
                        self.index += 1
                    case "-":
                        let n = try char(index + 1)
                        if n != nil && DIGITS.contains(n!) {
                            self.context = .decimal
                        } else {
                            self.context = .ident
                        }
                        self.buffer = String(c!)
                        self.index += 1
                    case "0"..."9", "+":
                        let n = try char(index + 1)
                        if c == "0" && n != nil && ["b", "o", "x"].contains(n) {
                            self.index += 2
                            self.buffer = ""
                            switch n {
                            case "b": self.context = .binary
                            case "o": self.context = .octal
                            case "x": self.context = .hexadecimal
                            default: ()
                            }
                        } else {
                            self.context = .decimal
                            self.index += 1
                            self.buffer = String(c!)
                        }
                    case "\\":
                        let t = KDLTokenizer(str, start: index + 1)
                        switch try t.nextToken() {
                        case .NEWLINE, .EOF:
                            self.context = .whitespace
                            self.index = t.index
                        case .WS:
                            self.buffer = String(c!)
                            switch try t.nextToken() {
                            case .NEWLINE, .EOF:
                                self.context = .whitespace
                                self.index = t.index
                            default: throw TokenizationError.unexpectedCharacter(c!)
                            }
                        default: throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case _ where EQUALS.contains(c!):
                        self.context = .equals
                        self.index += 1
                    case _ where SYMBOLS[c!] != nil: ()
                        self.index += 1
                        return SYMBOLS[c!]!
                    case _ where NEWLINES.contains(c!):
                        self.index += 1
                        return .NEWLINE
                    case "/":
                        switch try char(index + 1) {
                        case "/":
                            if inType || lastToken == .RPAREN {
                                throw TokenizationError.unexpectedCharacter(c!)
                            }
                            self.context = .singleLineComment
                            self.index += 2
                        case "*":
                            self.context = .multiLineComment
                            self.commentNesting = 1
                            self.index += 2
                        case "-":
                            self.index += 2
                            return .SLASHDASH
                        default: throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case _ where WHITESPACE.contains(c!):
                        self.context = .whitespace
                        self.index += 1
                    case _ where !NON_INITIAL_IDENTIFIER_CHARS.contains(c):
                        self.context = .ident
                        self.buffer = String(c!)
                        self.index += 1
                    case "(":
                        self.inType = true
                        self.index += 1
                        return .LPAREN
                    case ")":
                        self.inType = false
                        self.index += 1
                        return .RPAREN
                    default:
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                }
            } else {
                switch context {
                    case .ident:
                        if !NON_IDENTIFIER_CHARS.contains(c) {
                            self.index += 1
                            self.buffer += String(c!)
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
                            self.index += 1
                            self.buffer += String(c!)
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
                    case .some(.string), .some(.multiLineString):
                        switch c {
                        case "\\":
                            self.buffer += String(c!)
                            self.buffer += String(try char(index + 1)!)
                            self.index += 2
                        case "\"":
                            self.index += 1
                            var string = try KDLStringTokenizer(buffer).process()
                            string = self.context == .multiLineString ? try _unindent(string) : string
                            return .STRING(string)
                        case nil:
                            throw TokenizationError.unterminatedString
                        default:
                            self.buffer += String(c!)
                            self.index += 1
                        }
                    case .some(.rawstring), .some(.multiLineRawstring):
                        if c == nil {
                            throw TokenizationError.unterminatedRawstring
                        }

                        if c == "\"" {
                            var h = 0
                            while try char(index + 1 + h) == "#" && h < rawstringHashes {
                                h += 1
                            }
                            if h == self.rawstringHashes {
                                self.index += 1 + h
                                let string = self.context == .multiLineRawstring ? try _unindent(buffer) : buffer
                                return .RAWSTRING(string)
                            }
                        }

                        self.buffer += String(c!)
                        self.index += 1
                    case .some(.decimal):
                        if try c != nil && String(c!).contains(Regex("[0-9.\\-+_eE]")) {
                            self.index += 1
                            self.buffer += String(c!)
                        } else if c == nil || WHITESPACE.contains(c!) || NEWLINES.contains(c!) {
                            return try _parseDecimal(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.hexadecimal):
                        if try c != nil && String(c!).contains(Regex("[0-9a-fA-F_]")) {
                            self.index += 1
                            self.buffer += String(c!)
                        } else if c == nil || WHITESPACE.contains(c!) || NEWLINES.contains(c!) {
                            return try _parseHexadecimal(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.octal):
                        if try c != nil && String(c!).contains(Regex("[0-7_]")) {
                            self.index += 1
                            self.buffer += String(c!)
                        } else if c == nil || WHITESPACE.contains(c!) || NEWLINES.contains(c!) {
                            return try _parseOctal(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.binary):
                        if try c != nil && String(c!).contains(Regex("[01_]")) {
                            self.index += 1
                            self.buffer += String(c!)
                        } else if c == nil || WHITESPACE.contains(c!) || NEWLINES.contains(c!) {
                            return try _parseBinary(buffer)
                        } else {
                            throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case .some(.singleLineComment):
                        if c == nil {
                            self.done = true
                            return .EOF
                        } else if NEWLINES.contains(c!) || c == "\r" {
                            self.context = nil
                        } else {
                            self.index += 1
                        }
                    case .some(.multiLineComment):
                        switch (c, try char(index + 1)) {
                        case ("/", "*"):
                            self.commentNesting += 1
                            self.index += 2
                        case ("*", "/"):
                            self.commentNesting -= 1
                            self.index += 2
                            if commentNesting == 0 {
                                _revertContext()
                            }
                        default:
                            self.index += 1
                        }
                    case .some(.whitespace):
                        if c != nil && WHITESPACE.contains(c!) {
                            self.index += 1
                        } else if c != nil && EQUALS.contains(c!) {
                            self.context = .equals
                            self.index += 1
                        } else if c == "\\" {
                            let t = KDLTokenizer(str, start: index + 1)
                            switch try t.nextToken() {
                            case .NEWLINE, .EOF:
                                self.index = t.index
                            case .WS:
                                switch try t.nextToken() {
                                case .NEWLINE, .EOF:
                                    self.index = t.index
                                default: throw TokenizationError.unexpectedCharacter(c!)
                                }
                            default: throw TokenizationError.unexpectedCharacter(c!)
                            }
                        } else if try c == "/" && char(index + 1) == "*" {
                            self.context = .multiLineComment
                            self.commentNesting = 1
                            self.index += 2
                        } else {
                            return .WS
                        }
                    case .some(.equals):
                        let t = KDLTokenizer(str, start: index)
                        if try t.nextToken() == .WS {
                            self.index = t.index
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
        if FORBIDDEN.contains(c) {
            throw TokenizationError.forbiddenCharacter(c)
        }
        return c
    }

    func _revertContext() {
        self.context = previousContext
        self.previousContext = nil
    }

    func _parseDecimal(_ s: String) throws -> KDLToken {
        if s.contains(try Regex("[.eE]")) {
            if try _checkFloat(s), let f = Float(_munchUnderscores(s)) {
                return .FLOAT(f)
            }
        }
        if try _checkInt(s), let i = Int(_munchUnderscores(s)) {
            return .INTEGER(i)
        }
        if NON_INITIAL_IDENTIFIER_CHARS.contains(s.first) ||
            s[s.index(s.startIndex, offsetBy: 1)...].allSatisfy({ c in NON_IDENTIFIER_CHARS.contains(c) }) {
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
        if try !s.contains(Regex(#"^[0-9a-fA-F][0-9a-fA-F_]*$"#)) {
            throw TokenizationError.invalidHexadecimal(s)
        }
        if let i = Int(_munchUnderscores(s), radix: 16) {
            return .INTEGER(i)
        }
        throw TokenizationError.invalidHexadecimal(s)
    }

    func _parseOctal(_ s: String) throws -> KDLToken {
        if try !s.contains(Regex(#"^[0-7][0-7_]*$"#)) {
            throw TokenizationError.invalidOctal(s)
        }
        if let i = Int(_munchUnderscores(s), radix: 8) {
            return .INTEGER(i)
        }
        throw TokenizationError.invalidOctal(s)
    }

    func _parseBinary(_ s: String) throws -> KDLToken {
        if try !s.contains(Regex(#"^[01][01_]*$"#)) {
            throw TokenizationError.invalidBinary(s)
        }
        if let i = Int(_munchUnderscores(s), radix: 2) {
            return .INTEGER(i)
        }
        throw TokenizationError.invalidBinary(s)
    }

    func _munchUnderscores(_ s: String) -> String {
        return s.replacing("_", with: "")
    }

    func _unindent(_ string: String) throws -> String {
        var lines = string.split(separator: "\n")
        let indent = lines.last
        lines = lines.dropLast()

        if indent == nil {
            throw TokenizationError.invalidMultilineFinalLine
        }

        if indent != nil && !indent!.isEmpty {
            if !indent!.allSatisfy({ WHITESPACE.contains($0) }) {
                throw TokenizationError.invalidMultilineFinalLine
            }
            if !lines.allSatisfy({ $0.starts(with: indent!) }) {
                throw TokenizationError.invalidMultilineIndentation
            }
        }

        return lines.map({ $0.suffix(from: $0.index($0.startIndex, offsetBy: indent!.count)) }).joined(separator: "\n")
    }
}