import Testing
import BigDecimal
@testable import KDL

@Suite("Tokenizer v1 tests")
final class KDLTokenizerV1Tests {
    @Test func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizerV1("node 1 2 3")
        try #expect(tokenizer.peekToken() == .IDENT("node"))
        try #expect(tokenizer.peekTokenAfterNext() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("node"))
        try #expect(tokenizer.peekToken() == .WS)
        try #expect(tokenizer.peekTokenAfterNext() == .INTEGER(1))
    }

    @Test func testIdentifier() throws {
        try #expect(KDLTokenizerV1("foo").nextToken() == .IDENT("foo"))
        try #expect(KDLTokenizerV1("foo-bar123").nextToken() == .IDENT("foo-bar123"))
    }

    @Test func testString() throws {
        try #expect(KDLTokenizerV1(#""foo""#).nextToken() == .STRING("foo"))
        try #expect(KDLTokenizerV1(#""foo\nbar""#).nextToken() == .STRING("foo\nbar"))
        try #expect(KDLTokenizerV1(#""\u{10FFF}""#).nextToken() == .STRING("\u{10FFF}"))
    }

    @Test func testRawstring() throws {
        try #expect(KDLTokenizerV1(##"r"foo\nbar""##).nextToken() == .RAWSTRING(#"foo\nbar"#))
        try #expect(KDLTokenizerV1(##"r#"foo"bar"#"##).nextToken() == .RAWSTRING(#"foo"bar"#))
        try #expect(KDLTokenizerV1(###"r##"foo"#bar"##"###).nextToken() == .RAWSTRING(##"foo"#bar"##))
        try #expect(KDLTokenizerV1(##"r#""foo""#"##).nextToken() == .RAWSTRING(#""foo""#))

        var tokenizer = KDLTokenizerV1(##"node r"C:\Users\zkat\""##)
        try #expect(tokenizer.nextToken() == .IDENT("node"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .RAWSTRING(#"C:\Users\zkat\"#))

        tokenizer = KDLTokenizerV1(##"other-node r#"hello"world"#"##)
        try #expect(tokenizer.nextToken() == .IDENT("other-node"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .RAWSTRING(#"hello"world"#))
    }

    @Test func testInteger() throws {
        try #expect(KDLTokenizerV1("123").nextToken() == .INTEGER(123))
        try #expect(KDLTokenizerV1("0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        try #expect(KDLTokenizerV1("0o01234567").nextToken() == .INTEGER(0o01234567))
        try #expect(KDLTokenizerV1("0b101001").nextToken() == .INTEGER(0b101001))
        try #expect(KDLTokenizerV1("-0x0123456789abcdef").nextToken() == .INTEGER(-0x0123456789abcdef))
        try #expect(KDLTokenizerV1("-0o01234567").nextToken() == .INTEGER(-0o01234567))
        try #expect(KDLTokenizerV1("-0b101001").nextToken() == .INTEGER(-0b101001))
        try #expect(KDLTokenizerV1("+0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        try #expect(KDLTokenizerV1("+0o01234567").nextToken() == .INTEGER(0o01234567))
        try #expect(KDLTokenizerV1("+0b101001").nextToken() == .INTEGER(0b101001))
    }

    @Test func testFloat() throws {
        try #expect(KDLTokenizerV1("1.23").nextToken() == .DECIMAL(BigDecimal("1.23")))
    }

    @Test func testBooleazn() throws {
        try #expect(KDLTokenizerV1("true").nextToken() == .TRUE)
        try #expect(KDLTokenizerV1("false").nextToken() == .FALSE)
    }

    @Test func testNull() throws {
        try #expect(KDLTokenizerV1("null").nextToken() == .NULL)
    }

    @Test func testSymbols() throws {
        try #expect(KDLTokenizerV1("{").nextToken() == .LBRACE)
        try #expect(KDLTokenizerV1("}").nextToken() == .RBRACE)
        try #expect(KDLTokenizerV1("=").nextToken() == .EQUALS)
    }

    @Test func testWhitespace() throws {
        try #expect(KDLTokenizerV1(" ").nextToken() == .WS)
        try #expect(KDLTokenizerV1("\t").nextToken() == .WS)
        try #expect(KDLTokenizerV1("    \t").nextToken() == .WS)
        try #expect(KDLTokenizerV1("\\\n").nextToken() == .WS)
        try #expect(KDLTokenizerV1("\\").nextToken() == .WS)
        try #expect(KDLTokenizerV1("\\//some comment\n").nextToken() == .WS)
        try #expect(KDLTokenizerV1("\\ //some comment\n").nextToken() == .WS)
        try #expect(KDLTokenizerV1("\\//some comment").nextToken() == .WS)
    }

    @Test func testMultipleTokens() throws {
        let tokenizer = KDLTokenizerV1("node 1 \"two\" a=3")

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
        try #expect(KDLTokenizerV1("// comment").nextToken() == .EOF)

        let tokenizer = KDLTokenizerV1("""
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
        let tokenizer = KDLTokenizerV1("foo /*bar=1*/ baz=2");

        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("baz"))
        try #expect(tokenizer.nextToken() == .EQUALS)
        try #expect(tokenizer.nextToken() == .INTEGER(2))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testUtf8() throws {
        try #expect(KDLTokenizerV1("😁").nextToken() == .IDENT("😁"))
        try #expect(KDLTokenizerV1(#""😁""#).nextToken() == .STRING("😁"))
        try #expect(KDLTokenizerV1("ノード").nextToken() == .IDENT("ノード"))
        try #expect(KDLTokenizerV1("お名前").nextToken() == .IDENT("お名前"))
        try #expect(KDLTokenizerV1(#""☜(ﾟヮﾟ☜)""#).nextToken() == .STRING("☜(ﾟヮﾟ☜)"))

        let tokenizer = KDLTokenizerV1("""
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
        let tokenizer = KDLTokenizerV1("node1; node2");

        try #expect(tokenizer.nextToken() == .IDENT("node1"))
        try #expect(tokenizer.nextToken() == .SEMICOLON)
        try #expect(tokenizer.nextToken() == .WS)
        try #expect(tokenizer.nextToken() == .IDENT("node2"))
        try #expect(tokenizer.nextToken() == .EOF)
        try #expect(tokenizer.nextToken() == .NONE)
    }

    @Test func testSlashdash() throws {
        let tokenizer = KDLTokenizerV1("""
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
        let tokenizer = KDLTokenizerV1("""
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
        var tokenizer = KDLTokenizerV1("(foo)bar")
        try #expect(tokenizer.nextToken() == .LPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .RPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizerV1("(foo)/*asdf*/bar")
        try #expect(tokenizer.nextToken() == .LPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        try #expect(tokenizer.nextToken() == .RPAREN)
        #expect(throws: (any Error).self) { try tokenizer.nextToken() }

        tokenizer = KDLTokenizerV1("(foo/*asdf*/)bar")
        try #expect(tokenizer.nextToken() == .LPAREN)
        try #expect(tokenizer.nextToken() == .IDENT("foo"))
        #expect(throws: (any Error).self) { try tokenizer.nextToken() }
    }
}
