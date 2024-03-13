import XCTest
@testable import KDL

final class KDLTokenizerTests: XCTestCase {
    func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizer("node 1 2 3")
        XCTAssertEqual(try tokenizer.peekToken(), .IDENT("node"))
        XCTAssertEqual(try tokenizer.peekTokenAfterNext(), .WS)
    }

    func testIdentifier() throws {
        XCTAssertEqual(try KDLTokenizer("foo").nextToken(), .IDENT("foo"))
        XCTAssertEqual(try KDLTokenizer("foo-bar123").nextToken(), .IDENT("foo-bar123"))
        XCTAssertEqual(try KDLTokenizer("-").nextToken(), .IDENT("-"))
        XCTAssertEqual(try KDLTokenizer("--").nextToken(), .IDENT("--"))
    }

    func testString() throws {
        XCTAssertEqual(try KDLTokenizer(#""foo""#).nextToken(), .STRING("foo"))
        XCTAssertEqual(try KDLTokenizer(#""foo\nbar""#).nextToken(), .STRING("foo\nbar"))
        XCTAssertEqual(try KDLTokenizer(#""\u{10FFF}""#).nextToken(), .STRING("\u{10FFF}"))
    }

    func testRawstring() throws {
        XCTAssertEqual(try KDLTokenizer(##"#"foo\nbar"#"##).nextToken(), .RAWSTRING(#"foo\nbar"#))
        XCTAssertEqual(try KDLTokenizer(##"#"foo"bar"#"##).nextToken(), .RAWSTRING(#"foo"bar"#))
        XCTAssertEqual(try KDLTokenizer(###"##"foo"#bar"##"###).nextToken(), .RAWSTRING(##"foo"#bar"##))
        XCTAssertEqual(try KDLTokenizer(##"#""foo""#"##).nextToken(), .RAWSTRING(#""foo""#))

        var tokenizer = KDLTokenizer(##"node #"C:\Users\zkat\"#"##)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("node"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .RAWSTRING(#"C:\Users\zkat\"#))

        tokenizer = KDLTokenizer(##"other-node #"hello"world"#"##)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("other-node"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .RAWSTRING(#"hello"world"#))
    }

    func testInteger() throws {
        XCTAssertEqual(try KDLTokenizer("123").nextToken(), .INTEGER(123))
    }

    func testFloat() throws {
        XCTAssertEqual(try KDLTokenizer("1.23").nextToken(), .DECIMAL(1.23))
        XCTAssertEqual(try KDLTokenizer("#inf").nextToken(), .FLOAT(Float.infinity))
        XCTAssertEqual(try KDLTokenizer("#-inf").nextToken(), .FLOAT(-Float.infinity))
        let nan = try KDLTokenizer("#nan").nextToken()
        switch nan {
            case .FLOAT(let x): XCTAssert(x.isNaN)
            default: XCTFail("token was not a .FLOAT")
        }
    }

    func testBooleazn() throws {
        XCTAssertEqual(try KDLTokenizer("#true").nextToken(), .TRUE)
        XCTAssertEqual(try KDLTokenizer("#false").nextToken(), .FALSE)
    }

    func testNull() throws {
        XCTAssertEqual(try KDLTokenizer("#null").nextToken(), .NULL)
    }

    func testSymbols() throws {
        XCTAssertEqual(try KDLTokenizer("{").nextToken(), .LBRACE)
        XCTAssertEqual(try KDLTokenizer("}").nextToken(), .RBRACE)
    }

    func testEquals() throws {
        XCTAssertEqual(try KDLTokenizer("=").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer(" =").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer("= ").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer(" = ").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer(" =foo").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer("\u{FE66}").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer("\u{FF1D}").nextToken(), .EQUALS)
        XCTAssertEqual(try KDLTokenizer("🟰").nextToken(), .EQUALS)
    }

    func testWhitespace() throws {
        XCTAssertEqual(try KDLTokenizer(" ").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("\t").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("    \t").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("\\\n").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("\\").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("\\//some comment\n").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("\\ //some comment\n").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer("\\//some comment").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer(" \\\n").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer(" \\//some comment\n").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer(" \\ //some comment\n").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer(" \\//some comment").nextToken(), .WS)
        XCTAssertEqual(try KDLTokenizer(" \\\n  \\\n  ").nextToken(), .WS)
    }

    func testMultipleTokens() throws {
        let tokenizer = KDLTokenizer("node 1 \"two\" a=3")

        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("node"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .INTEGER(1))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .STRING("two"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("a"))
        XCTAssertEqual(try tokenizer.nextToken(), .EQUALS)
        XCTAssertEqual(try tokenizer.nextToken(), .INTEGER(3))
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testSingleLineComment() throws {
        XCTAssertEqual(try KDLTokenizer("// comment").nextToken(), .EOF)

        let tokenizer = KDLTokenizer("""
        node1
        // comment
        node2
        """)

        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("node1"))
        XCTAssertEqual(try tokenizer.nextToken(), .NEWLINE)
        XCTAssertEqual(try tokenizer.nextToken(), .NEWLINE)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("node2"))
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testMultilineComment() throws {
        let tokenizer = KDLTokenizer("foo /*bar=1*/ baz=2");

        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("foo"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("baz"))
        XCTAssertEqual(try tokenizer.nextToken(), .EQUALS)
        XCTAssertEqual(try tokenizer.nextToken(), .INTEGER(2))
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testUtf8() throws {
        XCTAssertEqual(try KDLTokenizer("😁").nextToken(), .IDENT("😁"))
        XCTAssertEqual(try KDLTokenizer(#""😁""#).nextToken(), .STRING("😁"))
        XCTAssertEqual(try KDLTokenizer("ノード").nextToken(), .IDENT("ノード"))
        XCTAssertEqual(try KDLTokenizer("お名前").nextToken(), .IDENT("お名前"))
        XCTAssertEqual(try KDLTokenizer(#""☜(ﾟヮﾟ☜)""#).nextToken(), .STRING("☜(ﾟヮﾟ☜)"))

        let tokenizer = KDLTokenizer("""
        smile "😁"
        ノード お名前＝"☜(ﾟヮﾟ☜)"
        """);

        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("smile"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .STRING("😁"))
        XCTAssertEqual(try tokenizer.nextToken(), .NEWLINE)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("ノード"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("お名前"))
        XCTAssertEqual(try tokenizer.nextToken(), .EQUALS)
        XCTAssertEqual(try tokenizer.nextToken(), .STRING("☜(ﾟヮﾟ☜)"))
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testSemicolon() throws {
        let tokenizer = KDLTokenizer("node1; node2");

        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("node1"))
        XCTAssertEqual(try tokenizer.nextToken(), .SEMICOLON)
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("node2"))
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testSlashdash() throws {
        let tokenizer = KDLTokenizer("""
        /-mynode /-"foo" /-key=1 /-{
            a
        }
        """)

        XCTAssertEqual(try tokenizer.nextToken(), .SLASHDASH)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("mynode"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .SLASHDASH)
        XCTAssertEqual(try tokenizer.nextToken(), .STRING("foo"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .SLASHDASH)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("key"))
        XCTAssertEqual(try tokenizer.nextToken(), .EQUALS)
        XCTAssertEqual(try tokenizer.nextToken(), .INTEGER(1))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .SLASHDASH)
        XCTAssertEqual(try tokenizer.nextToken(), .LBRACE)
        XCTAssertEqual(try tokenizer.nextToken(), .NEWLINE)
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("a"))
        XCTAssertEqual(try tokenizer.nextToken(), .NEWLINE)
        XCTAssertEqual(try tokenizer.nextToken(), .RBRACE)
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testMultilineNodes() throws {
        let tokenizer = KDLTokenizer("""
        title \\
            "Some title"
        """)

        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("title"))
        XCTAssertEqual(try tokenizer.nextToken(), .WS)
        XCTAssertEqual(try tokenizer.nextToken(), .STRING("Some title"))
        XCTAssertEqual(try tokenizer.nextToken(), .EOF)
        XCTAssertEqual(try tokenizer.nextToken(), .NONE)
    }

    func testTypes() throws {
        var tokenizer = KDLTokenizer("(foo)bar")
        XCTAssertEqual(try tokenizer.nextToken(), .LPAREN)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("foo"))
        XCTAssertEqual(try tokenizer.nextToken(), .RPAREN)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("bar"))

        tokenizer = KDLTokenizer("(foo)/*asdf*/bar")
        XCTAssertEqual(try tokenizer.nextToken(), .LPAREN)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("foo"))
        XCTAssertEqual(try tokenizer.nextToken(), .RPAREN)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("bar"))

        tokenizer = KDLTokenizer("(foo/*asdf*/)bar")
        XCTAssertEqual(try tokenizer.nextToken(), .LPAREN)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("foo"))
        XCTAssertEqual(try tokenizer.nextToken(), .RPAREN)
        XCTAssertEqual(try tokenizer.nextToken(), .IDENT("bar"))
    }
}
