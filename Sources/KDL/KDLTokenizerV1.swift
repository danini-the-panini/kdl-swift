public class KDLTokenizerV1 : KDLTokenizer {
    static let _SYMBOLS: [Character : KDLToken] = [
        "{": KDLToken.LBRACE,
        "}": KDLToken.RBRACE,
        "(": KDLToken.LPAREN,
        ")": KDLToken.RPAREN,
        ";": KDLToken.SEMICOLON,
        "=": KDLToken.EQUALS
    ]

    static let _NEWLINES : [Character] = ["\u{000A}", "\u{0085}", "\u{000C}", "\u{2028}", "\u{2029}", "\r", "\r\n"]
    static let _NEWLINES_PATTERN = "\(_NEWLINES.map{"\($0)"}.joined(separator: "|"))|\\r\\n?"

    static let _NON_IDENTIFIER_CHARS: [Character?] =
        [nil] +
        concat(
            WHITESPACE,
            NEWLINES,
            Array(_SYMBOLS.keys),
            ["\r", "\\", "<", ">", "[", "]", "\"", ",", "/"],
            charRange(from: 0x0000, to: 0x0020)
        )
    static let _NON_INITIAL_IDENTIFIER_CHARS: [Character?] = concat(
        _NON_IDENTIFIER_CHARS,
        DIGITS
    )

    static let _VERSION_PATTERN = "\\/-\(WS)*kdl-version\(WS)+(\\d+)\(WS)*\(_NEWLINES_PATTERN)"

    public override init(_ s: String, start: Int = 0) {
        super.init(s, start: start)
        self.version = 1
    }

    public override func versionDirective() throws -> UInt? {
        if let match = try Regex(KDLTokenizerV1._VERSION_PATTERN).prefixMatch(in: str) {
            if let version = match.output[1].substring {
                return UInt(version)
            }
        }
        return nil
    }

    override func _readNextToken() throws -> KDLToken {
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
                        self.context = .string
                        self.buffer = ""
                        try _traverse()
                    case "r":
                        switch try char(index + 1) {
                        case .some("\""):
                            self.context = .rawstring
                            try _traverse(2)
                            self.rawstringHashes = 0
                            self.buffer = ""
                            continue
                        case .some("#"):
                            var i = index + 1
                            self.rawstringHashes = 0
                            while try char(i) == "#" {
                                self.rawstringHashes += 1
                                i += 1
                            }
                            if try char(i) == "\"" {
                                self.context = .rawstring
                                self.buffer = ""
                                try _traverse(rawstringHashes + 2)
                                continue
                            }
                        default:
                            self.context = .ident
                            self.buffer = String(c!)
                            try _traverse()
                        }
                    case "-":
                        let n = try char(index + 1)
                        if n != nil && KDLTokenizer.DIGITS.contains(n!) {
                            let n2 = try char(index + 2)
                            if n == "0" && n2 != nil && ["b", "o", "x"].contains(n2!) {
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
                        if c == "0" && n != nil && ["b", "o", "x"].contains(n!) {
                            self.buffer = ""
                            self.context = try _integerContext(n!)
                            try _traverse(2)
                        } else if c == "+" && n == "0" && n2 != nil && ["b", "o", "x"].contains(n2!) {
                            self.buffer = String(c!)
                            self.context = try _integerContext(n2!)
                            try _traverse(3)
                        } else {
                            self.buffer = String(c!)
                            self.context = .decimal
                            try _traverse()
                        }
                    case "\\":
                        let t = KDLTokenizerV1(str, start: index + 1)
                        switch try t.nextToken() {
                        case .NEWLINE, .EOF:
                            self.context = .whitespace
                            try _traverseTo(t.index)
                            continue
                        case .WS:
                            switch try t.nextToken() {
                            case .NEWLINE, .EOF:
                                self.context = .whitespace
                                try _traverseTo(t.index)
                                continue
                            default: throw TokenizationError.unexpectedCharacter(c!)
                            }
                        default: throw TokenizationError.unexpectedCharacter(c!)
                        }
                    case _ where KDLTokenizerV1._SYMBOLS[c!] != nil:
                        if c == "(" {
                            self.inType = true
                        } else if c == ")" {
                            self.inType = false
                        }
                        try _traverse()
                        return KDLTokenizerV1._SYMBOLS[c!]!
                    case _ where KDLTokenizerV1._NEWLINES.contains(c!):
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
                            if inType || lastToken == .RPAREN {
                                throw TokenizationError.unexpectedCharacter(c!)
                            }
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
                    case _ where !KDLTokenizerV1._NON_INITIAL_IDENTIFIER_CHARS.contains(c!):
                        self.context = .ident
                        self.buffer = String(c!)
                        try _traverse()
                    default:
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                }
            } else {
                switch context {
                case .some(.ident):
                    if c == nil || KDLTokenizerV1._NON_IDENTIFIER_CHARS.contains(c!) {
                        switch buffer {
                        case "true": return .TRUE
                        case "false": return .FALSE
                        case "null": return .NULL
                        default: return .IDENT(buffer)
                        }
                    } else {
                        self.buffer += String(c!)
                        try _traverse()
                    }
                case .some(.string):
                    switch c {
                    case "\\":
                        self.buffer += String(c!)
                        var c2 = try char(index + 1)
                        self.buffer += String(c2!)
                        if KDLTokenizerV1._NEWLINES.contains(c2!) {
                            var i = 2
                            c2 = try char(index + i)
                            while KDLTokenizerV1._NEWLINES.contains(c2!) {
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
                        if h == rawstringHashes {
                            try _traverse(1 + h)
                            return .RAWSTRING(buffer)
                        }
                    }

                    self.buffer += String(c!)
                    try _traverse()
                case .some(.decimal):
                    if try c != nil && String(c!).contains(Regex("[0-9.\\-+_eE]")) {
                        self.buffer += String(c!)
                        try _traverse()
                    } else if c == nil ||
                        KDLTokenizer.WHITESPACE.contains(c!) ||
                        KDLTokenizerV1._NEWLINES.contains(c!) {
                            return try _parseDecimal(buffer)
                    } else {
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                case .some(.hexadecimal):
                    if try c != nil && String(c!).contains(Regex("[0-9a-fA-F_]")) {
                        self.buffer += String(c!)
                        try _traverse()
                    } else if c == nil ||
                        KDLTokenizer.WHITESPACE.contains(c!) ||
                        KDLTokenizerV1._NEWLINES.contains(c!) {
                            return try _parseHexadecimal(buffer)
                    } else {
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                case .some(.octal):
                    if try c != nil && String(c!).contains(Regex("[0-7_]")) {
                        self.buffer += String(c!)
                        try _traverse()
                    } else if c == nil ||
                        KDLTokenizer.WHITESPACE.contains(c!) ||
                        KDLTokenizerV1._NEWLINES.contains(c!) {
                            return try _parseOctal(buffer)
                    } else {
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                case .some(.binary):
                    if try c != nil && String(c!).contains(Regex("[01_]")) {
                        self.buffer += String(c!)
                        try _traverse()
                    } else if c == nil ||
                        KDLTokenizer.WHITESPACE.contains(c!) ||
                        KDLTokenizerV1._NEWLINES.contains(c!) {
                            return try _parseBinary(buffer)
                    } else {
                        throw TokenizationError.unexpectedCharacter(c!)
                    }
                case .some(.singleLineComment):
                    if c == nil {
                        self.done = true
                        return .EOF
                    } else if KDLTokenizerV1._NEWLINES.contains(c!) {
                        self.context = nil
                        self.columnAtStart = column
                    } else {
                        try _traverse()
                    }
                case .some(.multiLineComment):
                    switch (c, try char(index + 1)) {
                    case ("/", "*"):
                        self.commentNesting += 1
                        try _traverse(2)
                    case ("*",  "/"):
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
                    } else if c == "\\" {
                        let t = KDLTokenizerV1(str, start: index + 1)
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
                default:
                    throw TokenizationError.unexpectedNullContext
                }
            }
        }
    }
}
