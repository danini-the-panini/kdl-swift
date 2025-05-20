import Testing
import BigDecimal
@testable import KDL

@Suite("Tokenizer v1 tests")
final class KDLTokenizerV1Tests {
    @Test func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizerV1("node 1 2 3")
        #expect(try tokenizer.peekToken() == .IDENT("node"))
        #expect(try tokenizer.peekTokenAfterNext() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("node"))
        #expect(try tokenizer.peekToken() == .WS)
        #expect(try tokenizer.peekTokenAfterNext() == .INTEGER(1))
    }

    @Test func testIdentifier() throws {
        #expect(try KDLTokenizerV1("foo").nextToken() == .IDENT("foo"))
        #expect(try KDLTokenizerV1("foo-bar123").nextToken() == .IDENT("foo-bar123"))
    }

    @Test func testString() throws {
        #expect(try KDLTokenizerV1(#""foo""#).nextToken() == .STRING("foo"))
        #expect(try KDLTokenizerV1(#""foo\nbar""#).nextToken() == .STRING("foo\nbar"))
        #expect(try KDLTokenizerV1(#""\u{10FFF}""#).nextToken() == .STRING("\u{10FFF}"))
    }

    @Test func testRawstring() throws {
        #expect(try KDLTokenizerV1(##"r"foo\nbar""##).nextToken() == .RAWSTRING(#"foo\nbar"#))
        #expect(try KDLTokenizerV1(##"r#"foo"bar"#"##).nextToken() == .RAWSTRING(#"foo"bar"#))
        #expect(try KDLTokenizerV1(###"r##"foo"#bar"##"###).nextToken() == .RAWSTRING(##"foo"#bar"##))
        #expect(try KDLTokenizerV1(##"r#""foo""#"##).nextToken() == .RAWSTRING(#""foo""#))

        var tokenizer = KDLTokenizerV1(##"node r"C:\Users\zkat\""##)
        #expect(try tokenizer.nextToken() == .IDENT("node"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .RAWSTRING(#"C:\Users\zkat\"#))

        tokenizer = KDLTokenizerV1(##"other-node r#"hello"world"#"##)
        #expect(try tokenizer.nextToken() == .IDENT("other-node"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .RAWSTRING(#"hello"world"#))
    }

    @Test func testInteger() throws {
        #expect(try KDLTokenizerV1("123").nextToken() == .INTEGER(123))
        #expect(try KDLTokenizerV1("0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        #expect(try KDLTokenizerV1("0o01234567").nextToken() == .INTEGER(0o01234567))
        #expect(try KDLTokenizerV1("0b101001").nextToken() == .INTEGER(0b101001))
        #expect(try KDLTokenizerV1("-0x0123456789abcdef").nextToken() == .INTEGER(-0x0123456789abcdef))
        #expect(try KDLTokenizerV1("-0o01234567").nextToken() == .INTEGER(-0o01234567))
        #expect(try KDLTokenizerV1("-0b101001").nextToken() == .INTEGER(-0b101001))
        #expect(try KDLTokenizerV1("+0x0123456789abcdef").nextToken() == .INTEGER(0x0123456789abcdef))
        #expect(try KDLTokenizerV1("+0o01234567").nextToken() == .INTEGER(0o01234567))
        #expect(try KDLTokenizerV1("+0b101001").nextToken() == .INTEGER(0b101001))
    }

    @Test func testFloat() throws {
        #expect(try KDLTokenizerV1("1.23").nextToken() == .DECIMAL(BigDecimal("1.23")))
        #expect(try KDLTokenizerV1("#inf").nextToken() == .FLOAT(Float.infinity))
        #expect(try KDLTokenizerV1("#-inf").nextToken() == .FLOAT(-Float.infinity))
        let nan = try KDLTokenizerV1("#nan").nextToken()
        switch nan {
            case .FLOAT(let x): #expect(x.isNaN)
            default: Issue.record("token was not a .FLOAT")
        }
    }

    @Test func testBooleazn() throws {
        #expect(try KDLTokenizerV1("#true").nextToken() == .TRUE)
        #expect(try KDLTokenizerV1("#false").nextToken() == .FALSE)
    }

    @Test func testNull() throws {
        #expect(try KDLTokenizerV1("#null").nextToken() == .NULL)
    }

    @Test func testSymbols() throws {
        #expect(try KDLTokenizerV1("{").nextToken() == .LBRACE)
        #expect(try KDLTokenizerV1("}").nextToken() == .RBRACE)
    }

    @Test func testEquals() throws {
        #expect(try KDLTokenizerV1("=").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1(" =").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1("= ").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1(" = ").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1(" =foo").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1("\u{FE66}").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1("\u{FF1D}").nextToken() == .EQUALS)
        #expect(try KDLTokenizerV1("🟰").nextToken() == .EQUALS)
    }

    @Test func testWhitespace() throws {
        #expect(try KDLTokenizerV1(" ").nextToken() == .WS)
        #expect(try KDLTokenizerV1("\t").nextToken() == .WS)
        #expect(try KDLTokenizerV1("    \t").nextToken() == .WS)
        #expect(try KDLTokenizerV1("\\\n").nextToken() == .WS)
        #expect(try KDLTokenizerV1("\\").nextToken() == .WS)
        #expect(try KDLTokenizerV1("\\//some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizerV1("\\ //some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizerV1("\\//some comment").nextToken() == .WS)
        #expect(try KDLTokenizerV1(" \\\n").nextToken() == .WS)
        #expect(try KDLTokenizerV1(" \\//some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizerV1(" \\ //some comment\n").nextToken() == .WS)
        #expect(try KDLTokenizerV1(" \\//some comment").nextToken() == .WS)
        #expect(try KDLTokenizerV1(" \\\n  \\\n  ").nextToken() == .WS)
    }

    @Test func testMultipleTokens() throws {
        let tokenizer = KDLTokenizerV1("node 1 \"two\" a=3")

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

    @Test func testSingleLineComment() throws {
        #expect(try KDLTokenizerV1("// comment").nextToken() == .EOF)

        let tokenizer = KDLTokenizerV1("""
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

    @Test func testMultilineComment() throws {
        let tokenizer = KDLTokenizerV1("foo /*bar=1*/ baz=2");

        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("baz"))
        #expect(try tokenizer.nextToken() == .EQUALS)
        #expect(try tokenizer.nextToken() == .INTEGER(2))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    @Test func testUtf8() throws {
        #expect(try KDLTokenizerV1("😁").nextToken() == .IDENT("😁"))
        #expect(try KDLTokenizerV1(#""😁""#).nextToken() == .STRING("😁"))
        #expect(try KDLTokenizerV1("ノード").nextToken() == .IDENT("ノード"))
        #expect(try KDLTokenizerV1("お名前").nextToken() == .IDENT("お名前"))
        #expect(try KDLTokenizerV1(#""☜(ﾟヮﾟ☜)""#).nextToken() == .STRING("☜(ﾟヮﾟ☜)"))

        let tokenizer = KDLTokenizerV1("""
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

    @Test func testSemicolon() throws {
        let tokenizer = KDLTokenizerV1("node1; node2");

        #expect(try tokenizer.nextToken() == .IDENT("node1"))
        #expect(try tokenizer.nextToken() == .SEMICOLON)
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .IDENT("node2"))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    @Test func testSlashdash() throws {
        let tokenizer = KDLTokenizerV1("""
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

    @Test func testMultilineNodes() throws {
        let tokenizer = KDLTokenizerV1("""
        title \\
            "Some title"
        """)

        #expect(try tokenizer.nextToken() == .IDENT("title"))
        #expect(try tokenizer.nextToken() == .WS)
        #expect(try tokenizer.nextToken() == .STRING("Some title"))
        #expect(try tokenizer.nextToken() == .EOF)
        #expect(try tokenizer.nextToken() == .NONE)
    }

    @Test func testTypes() throws {
        var tokenizer = KDLTokenizerV1("(foo)bar")
        #expect(try tokenizer.nextToken() == .LPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .RPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizerV1("(foo)/*asdf*/bar")
        #expect(try tokenizer.nextToken() == .LPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .RPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("bar"))

        tokenizer = KDLTokenizerV1("(foo/*asdf*/)bar")
        #expect(try tokenizer.nextToken() == .LPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("foo"))
        #expect(try tokenizer.nextToken() == .RPAREN)
        #expect(try tokenizer.nextToken() == .IDENT("bar"))
    }
}
