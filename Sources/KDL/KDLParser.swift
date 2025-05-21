public class KDLParser {
    enum ParserError: Error, Sendable {
        case unexpectedToken(KDLToken)
        case expectedButGot(String, KDLToken)
        case versionMismatchError(UInt, UInt)
    }

    enum NodeResult {
        case Node(KDLNode)
        case Null
        case False
    }

    var tokenizer: KDLTokenizer!
    var depth = 0
    var outputVersion: UInt

    public init(outputVersion: UInt? = nil) {
        self.outputVersion = outputVersion ?? 2
    }

    public func parse(
        _ string: String,
        parseTypes: Bool = true
    ) throws -> KDLDocument {
        self.tokenizer = _createTokenizer(string)
        try _checkVersion()
        return try _document()
    }

    func _parserVersion() -> UInt {
        return 2
    }

    func _createTokenizer(_ string: String) -> KDLTokenizer {
        return KDLTokenizer(string)
    }

    func _checkVersion() throws {
        switch try tokenizer.versionDirective() {
        case .none:
            return
        case .some(let docVersion):
            if docVersion == _parserVersion() {
                return
            }
            throw ParserError.versionMismatchError(_parserVersion(), docVersion)
        }
    }

    func _document() throws -> KDLDocument {
        let nodes = try _nodeList()
        try _linespaceStar()
        try _expectEndOfFile()
        return KDLDocument(nodes, version: outputVersion)
    }

    func _nodeList() throws -> [KDLNode] {
        var nodes: [KDLNode] = []
        while true {
            switch try _node() {
            case .Node(let node): nodes.append(node)
            case .Null: continue
            case .False: return nodes
            }
        }
    }

    func _node() throws -> NodeResult {
        try _linespaceStar()

        var commented = false
        switch try tokenizer.peekToken() {
        case .SLASHDASH:
            try _slashdash()
            commented = true
        default: ()
        }

        var node: KDLNode!
        var type: String? = nil
        do {
            type = try _type()
            node = KDLNode(try _identifier(), version: outputVersion)
        } catch let e {
            if type != nil { throw e }
            return .False
        }

        try _argsPropsChildren(&node)

        if commented { return .Null }

        if type != nil {
            node.type = type
        }

        return .Node(node)
    }

    func _identifier() throws -> String {
        let t = try tokenizer.peekToken()
        switch t {
        case .IDENT(let s), .STRING(let s), .RAWSTRING(let s):
            let _ = try tokenizer.nextToken()
            return s
        default: throw ParserError.expectedButGot("identifier", t)
        }
    }

    func _wsStar() throws {
        var t = try tokenizer.peekToken()
        while t == .WS {
            let _ = try tokenizer.nextToken()
            t = try tokenizer.peekToken()
        }
    }

    func _linespaceStar() throws {
        while _isLinespace(try tokenizer.peekToken()) {
            let _ = try tokenizer.nextToken()
        }
    }

    func _isLinespace(_ t: KDLToken) -> Bool {
        return t == .NEWLINE || t == .WS
    }

    func _argsPropsChildren(_ node: inout KDLNode) throws {
        var commented = false
        var hasChildren = false
        while true {
            var peek = try tokenizer.peekToken()
            switch peek {
            case .WS, .SLASHDASH:
                try _wsStar()
                peek = try tokenizer.peekToken()
                if peek == .SLASHDASH {
                    try _slashdash()
                    peek = try tokenizer.peekToken()
                    commented = true
                }
                switch peek {
                case .STRING, .IDENT:
                    if hasChildren {
                        throw ParserError.unexpectedToken(peek)
                    }
                    switch try tokenizer.peekTokenAfterNext() {
                    case .EQUALS:
                        let p = try _prop()
                        if !commented {
                            node[p.0] = p.1
                        }
                    default:
                        let v = try _value()
                        if !commented {
                            node.arguments.append(v)
                        }
                    }
                    commented = false
                case .NEWLINE, .EOF, .SEMICOLON, .NONE:
                    let _ = try tokenizer.nextToken()
                    return
                case .LBRACE:
                    try _lbrace(&node, commented)
                    hasChildren = true
                    commented = false
                case .RBRACE:
                    try _rbrace()
                    return
                default:
                    let v = try _value()
                    if hasChildren {
                        throw ParserError.unexpectedToken(peek)
                    }
                    if !commented {
                        node.arguments.append(v)
                    }
                    commented = false
                }
            case .EOF, .SEMICOLON, .NEWLINE, .NONE:
                let _ = try tokenizer.nextToken()
                return
            case .LBRACE:
                try _lbrace(&node, commented)
                hasChildren = true
                commented = false
            case .RBRACE:
                try _rbrace()
                return
            default:
                throw ParserError.unexpectedToken(peek)
            }
        }
    }

    func _lbrace(_ node : inout KDLNode, _ commented: Bool) throws {
        if !commented && !node.children.isEmpty {
            throw ParserError.unexpectedToken(.LBRACE)
        }
        self.depth += 1
        let children = try _children()
        self.depth -= 1
        if !commented {
            node.children = children
        }
    }

    func _rbrace() throws {
        if depth == 0 {
            throw ParserError.unexpectedToken(.RBRACE)
        }
    }

    func _prop() throws -> (String, KDLValue) {
        let name = try _identifier()
        try _expect(.EQUALS)
        let value = try _value()
        return (name, value)
    }

    func _children() throws -> [KDLNode] {
        try _expect(.LBRACE)
        let nodes = try _nodeList()
        try _linespaceStar()
        try _expect(.RBRACE)
        return nodes
    }

    func _value() throws -> KDLValue {
        let type = try _type()
        let t = try tokenizer.nextToken()
        let v = try _valueWithoutType(t)
        switch type {
        case .none:
            return v
        case .some(let ty):
            return v.asType(ty)
        }
    }

    func _valueWithoutType(_ t: KDLToken) throws -> KDLValue {
        switch t {
        case .IDENT(let s), .STRING(let s), .RAWSTRING(let s):
            return .string(s, nil, outputVersion)
        case .INTEGER(let i): return .int(i, nil, outputVersion)
        case .BIGINT(let i): return .bigint(i, nil, outputVersion)
        case .FLOAT(let f): return .float(f, nil, outputVersion)
        case .DECIMAL(let d): return .decimal(d, nil, outputVersion)
        case .TRUE: return .bool(true, nil, outputVersion)
        case .FALSE: return .bool(false, nil, outputVersion)
        case .NULL: return .null(nil, outputVersion)
        default:
            throw ParserError.expectedButGot("value", t)
        }
    }

    func _type() throws -> String? {
        if try tokenizer.peekToken() != .LPAREN { return nil }
        try _expect(.LPAREN)
        try _wsStar()
        let type = try _identifier()
        try _wsStar()
        try _expect(.RPAREN)
        try _wsStar()
        return type
    }

    func _slashdash() throws {
        let t = try tokenizer.nextToken()
        if t != .SLASHDASH {
            throw ParserError.expectedButGot("slashdash", t)
        }
        try _linespaceStar()
        let peek = try tokenizer.peekToken()
        switch peek {
        case .RBRACE, .EOF, .SEMICOLON, .NONE:
            throw ParserError.unexpectedToken(peek)
        default: ()
        }
    }

    func _expect(_ type: KDLToken) throws {
        let t = try tokenizer.peekToken()
        if t != type {
            throw ParserError.unexpectedToken(t)
        }
        let _ = try tokenizer.nextToken()
    }

    func _expectEndOfFile() throws {
        let t = try tokenizer.peekToken()
        switch t {
        case .EOF, .NONE: ()
        default: throw ParserError.expectedButGot("EOF", t)
        }
    }
}
