public class KDLParserV1 : KDLParser {
    public override init(outputVersion: UInt? = nil) {
        super.init(outputVersion: outputVersion ?? 1)
    }

    override func _parserVersion() -> UInt {
        return 1
    }

    override func _createTokenizer(_ string: String) -> KDLTokenizer {
        return KDLTokenizerV1(string)
    }

    override func _argsPropsChildren(_ node: inout KDLNode) throws {
        var commented = false
        while true {
            try _wsStar()
            switch try tokenizer.peekToken() {
            case .IDENT:
                let p = try _prop()
                if !commented {
                    node[p.0] = p.1
                }
                commented = false
            case .LBRACE:
                let childNodes = try _children()
                if !commented {
                    node.children = childNodes
                }
                try _expectNodeTerm()
                return
            case .SLASHDASH:
                commented = true
                let _ = try tokenizer.nextToken()
                try _wsStar()
            case .NEWLINE, .SEMICOLON, .EOF, .NONE:
                let _ = try tokenizer.nextToken()
                return
            case .STRING:
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
            default:
                let v = try _value()
                if !commented {
                    node.arguments.append(v)
                }
                commented = false
            }
        }
    }

    override func _valueWithoutType(_ t: KDLToken) throws -> KDLValue {
        switch t {
        case .STRING(let value), .RAWSTRING(let value):
            return .string(value, nil, outputVersion)
        case .INTEGER(let value): return .int(value, nil, outputVersion)
        case .BIGINT(let value): return .bigint(value, nil, outputVersion)
        case .DECIMAL(let value): return .decimal(value, nil, outputVersion)
        case .FLOAT(let value): return .float(value, nil, outputVersion)
        case .TRUE: return .bool(true, nil, outputVersion)
        case .FALSE: return .bool(false, nil, outputVersion)
        case .NULL: return .null(nil, outputVersion)
        default: throw ParserError.expectedButGot("value", t)
        }
    }

    override func _type() throws -> String? {
        if try tokenizer.peekToken() != .LPAREN {
            return nil
        }
        try _expect(.LPAREN)
        let type = try _identifier()
        try _expect(.RPAREN)
        return type
    }

    func _expectNodeTerm() throws {
        try _wsStar()
        let t = try tokenizer.peekToken()
        switch t {
        case .NEWLINE, .SEMICOLON, .EOF, .NONE:
            let _ = try tokenizer.nextToken()
        default:
            throw ParserError.unexpectedToken(t)
        }
    }
}
