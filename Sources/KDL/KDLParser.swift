public class KDLParser {
    enum ParserError: Error {
        case unexpectedToken(KDLToken)
        case expectedButGot(String, KDLToken)
    }

    enum NodeResult {
        case Node(KDLNode)
        case Null
        case False
    }

    var tokenizer: KDLTokenizer!
    var depth = 0

    public func parse(
        _ string: String,
        parseTypes: Bool = true
    ) throws -> KDLDocument {
        self.tokenizer = KDLTokenizer(string)
        return try _document()
    }

    func _document() throws -> KDLDocument {
        let nodes = try _nodes()
        try _linespaceStar()
        try _expectEndOfFile()
        return KDLDocument(nodes)
    }

    func _nodes() throws -> [KDLNode] {
        var nodes: [KDLNode] = []
        while true {
            let n = try _node()
            switch n {
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
            let _ = try tokenizer.nextToken()
            try _wsStar()
            commented = true
        default: ()
        }

        var node: KDLNode!
        var type: String? = nil
        do {
            type = try _type()
            node = KDLNode(try _identifier())
        } catch let e {
            if type != nil { throw e }
            return .False
        }

        switch try tokenizer.peekToken() {
        case .WS, .LBRACE: try _argsPropsChildren(&node)
        case .SEMICOLON: let _ = try tokenizer.nextToken()
        case .LPAREN: throw ParserError.unexpectedToken(.LPAREN)
        default: ()
        }

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
        while true {
            try _wsStar()
            switch try tokenizer.peekToken() {
            case .IDENT:
                switch try tokenizer.peekTokenAfterNext() {
                case .EQUALS:
                    let p = try _prop()
                    if !commented {
                        node.properties[p.0] = p.1
                    }
                default:
                    let v = try _value()
                    if !commented {
                        node.arguments.append(v)
                    }
                }
            case .LBRACE:
                self.depth += 1
                let children = try _children()
                if !commented {
                    node.children = children
                }
                try _expectNodeTerm()
                return
            case .RBRACE:
                if depth == 0 { throw ParserError.unexpectedToken(.RBRACE) }
                self.depth -= 1
                return
            case .SLASHDASH:
                commented = true
                let _ = try tokenizer.nextToken()
                try _wsStar()
            case .NEWLINE, .EOF, .SEMICOLON:
                let _ = try tokenizer.nextToken()
                return
            case .STRING:
                switch try tokenizer.peekTokenAfterNext() {
                case .EQUALS:
                    let p = try _prop()
                    if !commented {
                        node.properties[p.0] = p.1
                    }
                default:
                    let v = try _value()
                    if !commented {
                        node.arguments.append(v)
                    }
                }
                commented = false
            default:
                let v = try _value()
                if !commented {
                    node.arguments.append(v)
                }
                commented = false
            }
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
        let nodes = try _nodes()
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
            return .string(s)
        case .INTEGER(let i): return .int(i)
        case .FLOAT(let f): return .float(f)
        case .TRUE: return .bool(true)
        case .FALSE: return .bool(false)
        case .NULL: return .null()
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

    func _expect(_ type: KDLToken) throws {
        let t = try tokenizer.peekToken()
        if t != type {
            throw ParserError.unexpectedToken(t)
        }
        let _ = try tokenizer.nextToken()
    }

    func _expectNodeTerm() throws {
        try _wsStar()
        let t = try tokenizer.peekToken()
        switch t {
        case .NEWLINE, .SEMICOLON, .EOF:
            let _ = try tokenizer.nextToken()
        case .RBRACE: ()
        default: throw ParserError.unexpectedToken(t)
        }
    }

    func _expectEndOfFile() throws {
        let t = try tokenizer.peekToken()
        switch t {
        case .EOF, .NONE: ()
        default: throw ParserError.expectedButGot("EOF", t)
        }
    }

}