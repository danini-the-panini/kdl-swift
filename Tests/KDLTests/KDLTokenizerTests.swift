import Testing
import BigDecimal
@testable import KDL

@Suite("Tokenizer tests")
final class KDLTokenizerTests {
    func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizer("node 1 2 3")
        #expect(try tokenizer.peekToken() == .IDENT("node"))
        #expect(try tokenizer.peekTokenAfterNext() == .WS)
    }

    func testIdentifier() throws {
        #expect(try KDLTokenizer("foo").nextToken() == .IDENT("foo"))
        #expect(try KDLTokenizer("foo-bar123").nextToken() == .IDENT("foo-bar123"))
        #expect(try KDLTokenizer("-").nextToken() == .IDENT("-"))
        #expect(try KDLTokenizer("--").nextToken() == .IDENT("--"))
    }

    func testString() throws {
        #expect(try KDLTokenizer(#""foo""#).nextToken() == .STRING("foo"))
        #expect(try KDLTokenizer(#""foo\nbar""#).nextToken() == .STRING("foo\nbar"))
        #expect(try KDLTokenizer(#""\u{10FFF}""#).nextToken() == .STRING("\u{10FFF}"))
    }

    func testRawstring() throws {
        #expect(try KDLTokenizer(##"#"foo\nbar"#"##).nextToken() == .RAWSTRING(#"foo\nbar"#))
        #expect(try KDLTokenizer(##"#"foo"bar"#"##).nextToken() == .RAWSTRING(#"foo"bar"#))
        #expect(try KDLTokenizer(###"##"foo"#bar"##"###).nextToken() == .RAWSTRING(##"foo"#bar"##))
        #expect(try KDLTokenizer(##"#""foo""#"##).nextToken() == .RAWSTRING(#""foo""#))

        var tokenizer = KDLTokenizer(##"node #"C:\Users\zkat\"#"##)
        #expect(try tokenizer.nextToken() == .IDENT("node"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .RAWSTRING(#"C:\Users\zkat\"#))

        tokenizer = KDLTokenizer(##"other-node #"hello"world"#"##)
        #expect(try tokenizer.nextToken() == .IDENT("other-node"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .RAWSTRING(#"hello"world"#))
    }

    func testInteger() throws {
        #expect(try KDLTokenizer("123").nextToken() == .INTEGER(123))
        #expect(try KDLTokenizer("0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        #expect(try KDLTokenizer("0o01234567").nextToken() == .INTEGER(0o01234567))
        #expect(try KDLTokenizer("0b101001").nextToken() == .INTEGER(0b101001))
        #expect(try KDLTokenizer("-0x0123456789abcdef").nextToken() == .INTEGER(-0x0123456789abcdef))
        #expect(try KDLTokenizer("-0o01234567").nextToken() == .INTEGER(-0o01234567))
        #expect(try KDLTokenizer("-0b101001").nextToken() == .INTEGER(-0b101001))
        #expect(try KDLTokenizer("+0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        #expect(try KDLTokenizer("+0o01234567").nextToken() == .INTEGER(0o01234567))
        #expect(try KDLTokenizer("+0b101001").nextToken() == .INTEGER(0b101001))
    }

    func testFloat() throws {
        #expect(try KDLTokenizer("1.23").nextToken() == .DECIMAL(BigDecimal("1.23")))
        #expect(try KDLTokenizer("#inf").nextToken() == .FLOAT(Float.infinity))
        #expect(try KDLTokenizer("#-inf").nextToken() == .FLOAT(-Float.infinity))
        let nan = try KDLTokenizer("#nan").nextToken()
        switch nan {
            case .FLOAT(let x): #expect(x.isNaN)
            default: Issue.record("token was not a .FLOAT")
        }
    }

    func testBooleazn() throws {
        #expect(try KDLTokenizer("#true").nextToken() == .TRUE)
        #expect(try KDLTokenizer("#false").nextToken() == .FALSE)
    }

    func testNull() throws {
        #expect(try KDLTokenizer("#null").nextToken() == .NULL)
    }

    func testSymbols() throws {
        #expect(try KDLTokenizer("{").nextToken() == .LBRACE)
        #expect(try KDLTokenizer("}").nextToken() == .RBRACE)
    }

    func testEquals() throws {
        #expect(try KDLTokenizer("=").nextToken() == .EQUALS)
        #expect(try KDLTokenizer(" =").nextToken() == .EQUALS)
        #expect(try KDLTokenizer("= ").nextToken() == .EQUALS)
        #expect(try KDLTokenizer(" = ").nextToken() == .EQUALS)
        #expect(try KDLTokenizer(" =foo").nextToken() == .EQUALS)
        #expect(try KDLTokenizer("\u{FE66}").nextToken() == .EQUALS)
        #expect(try KDLTokenizer("\u{FF1D}").nextToken() == .EQUALS)
        #expect(try KDLTokenizer("🟰").nextToken() == .EQUALS)
    }

    func testWhitespace() throws {
        #expect(try KDLTokenizer(" ").nextToken() == .WS)
        #expect(try KDLTokenizer("\t").nextToken() == .WS)
        #expect(try KDLTokenizer("    \t").nextToken() == .WS)
        #expect(try KDLTokenizer("\\\n").nextToken() == .WS)
        #expect(try KDLTokenizer("\\").nextToken() == .WS)
        #expect(try KDLTokenizer("\\//some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizer("\\ //some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizer("\\//some comment").nextToken() == .WS)
        #expect(try KDLTokenizer(" \\\n").nextToken() == .WS)
        #expect(try KDLTokenizer(" \\//some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizer(" \\ //some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizer(" \\//some comment").nextToken() == .WS)
        #expect(try KDLTokenizer(" \\\n  \\\n  ").nextToken() == .WS)
    }

    func testMultipleTokens() throws {
        let tokenizer = KDLTokenizer("node 1 \"two\" a=3")

        #expect(try tokenizer.nextToken() == .IDENT("node"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .INTEGER(1))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .STRING("two"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("a"))
        #expect(try tokenizer.nextToken() == .EQUALS)
        #expect(try tokenizer.nextToken() == .INTEGER(3))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testSingleLineComment() throws {
        #expect(try KDLTokenizer("// comment").nextToken() == .EOF)

        let tokenizer = KDLTokenizer("""
        node1
        // comment
        node2
        """)

        #expect(try tokenizer.nextToken() == .IDENT("node1"))
        #expect(try tokenizer.nextToken() == .NEWLINE)
        #expect(try tokenizer.nextToken() == .NEWLINE)
        #expect(try tokenizer.nextToken() == .IDENT("node2"))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testMultilineComment() throws {
        let tokenizer = KDLTokenizer("foo /*bar=1*/ baz=2");

        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("baz"))
        #expect(try tokenizer.nextToken() == .EQUALS)
        #expect(try tokenizer.nextToken() == .INTEGER(2))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testUtf8() throws {
        #expect(try KDLTokenizer("😁").nextToken() == .IDENT("😁"))
        #expect(try KDLTokenizer(#""😁""#).nextToken() == .STRING("😁"))
        #expect(try KDLTokenizer("ノード").nextToken() == .IDENT("ノード"))
        #expect(try KDLTokenizer("お名前").nextToken() == .IDENT("お名前"))
        #expect(try KDLTokenizer(#""☜(ﾟヮﾟ☜)""#).nextToken() == .STRING("☜(ﾟヮﾟ☜)"))

        let tokenizer = KDLTokenizer("""
        smile "😁"
        ノード お名前＝"☜(ﾟヮﾟ☜)"
        """);

        #expect(try tokenizer.nextToken() == .IDENT("smile"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .STRING("😁"))
        #expect(try tokenizer.nextToken() == .NEWLINE)
        #expect(try tokenizer.nextToken() == .IDENT("ノード"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("お名前"))
        #expect(try tokenizer.nextToken() == .EQUALS)
        #expect(try tokenizer.nextToken() == .STRING("☜(ﾟヮﾟ☜)"))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testSemicolon() throws {
        let tokenizer = KDLTokenizer("node1; node2");

        #expect(try tokenizer.nextToken() == .IDENT("node1"))
        #expect(try tokenizer.nextToken() == .SEMICOLON)
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("node2"))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testSlashdash() throws {
        let tokenizer = KDLTokenizer("""
        /-mynode /-"foo" /-key=1 /-{
            a
        }
        """)

        #expect(try tokenizer.nextToken() == .SLASHDASH)
        #expect(try tokenizer.nextToken() == .IDENT("mynode"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .SLASHDASH)
        #expect(try tokenizer.nextToken() == .STRING("foo"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .SLASHDASH)
        #expect(try tokenizer.nextToken() == .IDENT("key"))
        #expect(try tokenizer.nextToken() == .EQUALS)
        #expect(try tokenizer.nextToken() == .INTEGER(1))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .SLASHDASH)
        #expect(try tokenizer.nextToken() == .LBRACE)
        #expect(try tokenizer.nextToken() == .NEWLINE)
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("a"))
        #expect(try tokenizer.nextToken() == .NEWLINE)
        #expect(try tokenizer.nextToken() == .RBRACE)
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testMultilineNodes() throws {
        let tokenizer = KDLTokenizer("""
        title \\
            "Some title"
        """)

        #expect(try tokenizer.nextToken() == .IDENT("title"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .STRING("Some title"))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    func testTypes() throws {
        var tokenizer = KDLTokenizer("(foo)bar")
        #expect(try tokenizer.nextToken() == .LPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .RPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizer("(foo)/*asdf*/bar")
        #expect(try tokenizer.nextToken() == .LPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .RPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizer("(foo/*asdf*/)bar")
        #expect(try tokenizer.nextToken() == .LPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .RPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("bar"))
    }
}
