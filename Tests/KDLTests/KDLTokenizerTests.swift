import Testing
import BigDecimal
@testable import KDL

@Suite("Tokenizer tests")
final class KDLTokenizerTests {
    @Test func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizer("node 1 2 3")
        try #expect(tokenizer.peekToken() == .IDENT("node"))
        try #expect(tokenizer.peekTokenAfterNext() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("node"))
        try #expect(tokenizer.peekToken() == .WS)
        try #expect(tokenizer.peekTokenAfterNext() == .INTEGER(1))
    }

    @Test func testIdentifier() throws {
        try #expect(KDLTokenizer("foo").nextToken() == .IDENT("foo"))
        try #expect(KDLTokenizer("foo-bar123").nextToken() == .IDENT("foo-bar123"))
        try #expect(KDLTokenizer("-").nextToken() == .IDENT("-"))
        try #expect(KDLTokenizer("--").nextToken() == .IDENT("--"))
    }

    @Test func testString() throws {
        try #expect(KDLTokenizer(#""foo""#).nextToken() == .STRING("foo"))
        try #expect(KDLTokenizer(#""foo\nbar""#).nextToken() == .STRING("foo\nbar"))
        try #expect(KDLTokenizer(#""\u{10FFF}""#).nextToken() == .STRING("\u{10FFF}"))
        try #expect(KDLTokenizer("\"\\\n\n\nfoo\"").nextToken() == .STRING("foo"))
    }

    @Test func testRawstring() throws {
        try #expect(KDLTokenizer(##"#"foo\nbar"#"##).nextToken() == .RAWSTRING(#"foo\nbar"#))
        try #expect(KDLTokenizer(##"#"foo"bar"#"##).nextToken() == .RAWSTRING(#"foo"bar"#))
        try #expect(KDLTokenizer(###"##"foo"#bar"##"###).nextToken() == .RAWSTRING(##"foo"#bar"##))
        try #expect(KDLTokenizer(##"#""foo""#"##).nextToken() == .RAWSTRING(#""foo""#))

        var tokenizer = KDLTokenizer(##"node #"C:\Users\zkat\"#"##)
        try #expect(tokenizer.nextToken() == .IDENT("node"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .RAWSTRING(#"C:\Users\zkat\"#))

        tokenizer = KDLTokenizer(##"other-node #"hello"world"#"##)
        try #expect(tokenizer.nextToken() == .IDENT("other-node"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .RAWSTRING(#"hello"world"#))
    }

    @Test func testInteger() throws {
        try #expect(KDLTokenizer("123").nextToken() == .INTEGER(123))
        try #expect(KDLTokenizer("0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        try #expect(KDLTokenizer("0o01234567").nextToken() == .INTEGER(0o01234567))
        try #expect(KDLTokenizer("0b101001").nextToken() == .INTEGER(0b101001))
        try #expect(KDLTokenizer("-0x0123456789abcdef").nextToken() == .INTEGER(-0x0123456789abcdef))
        try #expect(KDLTokenizer("-0o01234567").nextToken() == .INTEGER(-0o01234567))
        try #expect(KDLTokenizer("-0b101001").nextToken() == .INTEGER(-0b101001))
        try #expect(KDLTokenizer("+0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        try #expect(KDLTokenizer("+0o01234567").nextToken() == .INTEGER(0o01234567))
        try #expect(KDLTokenizer("+0b101001").nextToken() == .INTEGER(0b101001))
    }

    @Test func testFloat() throws {
        try #expect(KDLTokenizer("1.23").nextToken() == .DECIMAL(BigDecimal("1.23")))
        try #expect(KDLTokenizer("#inf").nextToken() == .FLOAT(Float.infinity))
        try #expect(KDLTokenizer("#-inf").nextToken() == .FLOAT(-Float.infinity))
        let nan = try KDLTokenizer("#nan").nextToken()
        switch nan {
            case .FLOAT(let x): #expect(x.isNaN)
            default: Issue.record("token was not a .FLOAT")
        }
    }

    @Test func testBooleazn() throws {
        try #expect(KDLTokenizer("#true").nextToken() == .TRUE)
        try #expect(KDLTokenizer("#false").nextToken() == .FALSE)
    }

    @Test func testNull() throws {
        try #expect(KDLTokenizer("#null").nextToken() == .NULL)
    }

    @Test func testSymbols() throws {
        try #expect(KDLTokenizer("{").nextToken() == .LBRACE)
        try #expect(KDLTokenizer("}").nextToken() == .RBRACE)
    }

    @Test func testEquals() throws {
        try #expect(KDLTokenizer("=").nextToken() == .EQUALS)
        try #expect(KDLTokenizer(" =").nextToken() == .EQUALS)
        try #expect(KDLTokenizer("= ").nextToken() == .EQUALS)
        try #expect(KDLTokenizer(" = ").nextToken() == .EQUALS)
        try #expect(KDLTokenizer(" =foo").nextToken() == .EQUALS)
    }

    @Test func testWhitespace() throws {
        try #expect(KDLTokenizer(" ").nextToken() == .WS)
        try #expect(KDLTokenizer("\t").nextToken() == .WS)
        try #expect(KDLTokenizer("    \t").nextToken() == .WS)
        try #expect(KDLTokenizer("\\\n").nextToken() == .WS)
        try #expect(KDLTokenizer("\\").nextToken() == .WS)
        try #expect(KDLTokenizer("\\//some comment\n").nextToken() == .WS)
        try #expect(KDLTokenizer("\\ //some comment\n").nextToken() == .WS)
        try #expect(KDLTokenizer("\\//some comment").nextToken() == .WS)
        try #expect(KDLTokenizer(" \\\n").nextToken() == .WS)
        try #expect(KDLTokenizer(" \\//some comment\n").nextToken() == .WS)
        try #expect(KDLTokenizer(" \\ //some comment\n").nextToken() == .WS)
        try #expect(KDLTokenizer(" \\//some comment").nextToken() == .WS)
        try #expect(KDLTokenizer(" \\\n  \\\n  ").nextToken() == .WS)
    }

    @Test func testMultipleTokens() throws {
        let tokenizer = KDLTokenizer("node 1 \"two\" a=3")

        try #expect(tokenizer.nextToken() == .IDENT("node"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .INTEGER(1))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .STRING("two"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("a"))
        try #expect(tokenizer.nextToken() == .EQUALS)
        try #expect(tokenizer.nextToken() == .INTEGER(3))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testSingleLineComment() throws {
        try #expect(KDLTokenizer("// comment").nextToken() == .EOF)

        let tokenizer = KDLTokenizer("""
        node1
        // comment
        node2
        """)

        try #expect(tokenizer.nextToken() == .IDENT("node1"))
        try #expect(tokenizer.nextToken() == .NEWLINE)
        try #expect(tokenizer.nextToken() == .NEWLINE)
        try #expect(tokenizer.nextToken() == .IDENT("node2"))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testMultilineComment() throws {
        let tokenizer = KDLTokenizer("foo /*bar=1*/ baz=2");

        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("baz"))
        try #expect(tokenizer.nextToken() == .EQUALS)
        try #expect(tokenizer.nextToken() == .INTEGER(2))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testUtf8() throws {
        try #expect(KDLTokenizer("😁").nextToken() == .IDENT("😁"))
        try #expect(KDLTokenizer(#""😁""#).nextToken() == .STRING("😁"))
        try #expect(KDLTokenizer("ノード").nextToken() == .IDENT("ノード"))
        try #expect(KDLTokenizer("お名前").nextToken() == .IDENT("お名前"))
        try #expect(KDLTokenizer(#""☜(ﾟヮﾟ☜)""#).nextToken() == .STRING("☜(ﾟヮﾟ☜)"))

        let tokenizer = KDLTokenizer("""
        smile "😁"
        ノード お名前="☜(ﾟヮﾟ☜)"
        """);

        try #expect(tokenizer.nextToken() == .IDENT("smile"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .STRING("😁"))
        try #expect(tokenizer.nextToken() == .NEWLINE)
        try #expect(tokenizer.nextToken() == .IDENT("ノード"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("お名前"))
        try #expect(tokenizer.nextToken() == .EQUALS)
        try #expect(tokenizer.nextToken() == .STRING("☜(ﾟヮﾟ☜)"))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testSemicolon() throws {
        let tokenizer = KDLTokenizer("node1; node2");

        try #expect(tokenizer.nextToken() == .IDENT("node1"))
        try #expect(tokenizer.nextToken() == .SEMICOLON)
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("node2"))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testSlashdash() throws {
        let tokenizer = KDLTokenizer("""
        /-mynode /-"foo" /-key=1 /-{
            a
        }
        """)

        try #expect(tokenizer.nextToken() == .SLASHDASH)
        try #expect(tokenizer.nextToken() == .IDENT("mynode"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .SLASHDASH)
        try #expect(tokenizer.nextToken() == .STRING("foo"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .SLASHDASH)
        try #expect(tokenizer.nextToken() == .IDENT("key"))
        try #expect(tokenizer.nextToken() == .EQUALS)
        try #expect(tokenizer.nextToken() == .INTEGER(1))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .SLASHDASH)
        try #expect(tokenizer.nextToken() == .LBRACE)
        try #expect(tokenizer.nextToken() == .NEWLINE)
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("a"))
        try #expect(tokenizer.nextToken() == .NEWLINE)
        try #expect(tokenizer.nextToken() == .RBRACE)
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testMultilineNodes() throws {
        let tokenizer = KDLTokenizer("""
        title \\
            "Some title"
        """)

        try #expect(tokenizer.nextToken() == .IDENT("title"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .STRING("Some title"))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testTypes() throws {
        var tokenizer = KDLTokenizer("(foo)bar")
        try #expect(tokenizer.nextToken() == .LPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .RPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizer("(foo)/*asdf*/bar")
        try #expect(tokenizer.nextToken() == .LPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .RPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizer("(foo/*asdf*/)bar")
        try #expect(tokenizer.nextToken() == .LPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .RPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("bar"))
    }
}
