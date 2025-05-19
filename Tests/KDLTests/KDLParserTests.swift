import Foundation
import BigDecimal
import Testing
@testable import KDL

@Suite("Parser tests")
struct KDLParserTests {
    @Test static func testParseEmptyString() throws {
        let parser = KDLParser()
        #expect(try parser.parse("") == KDLDocument([]))
        #expect(try parser.parse(" ") == KDLDocument([]))
        #expect(try parser.parse("\n") == KDLDocument([]))
    }

    @Test static func testNodes() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node\n") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("\nnode") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node1\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        #expect(try parser.parse("node;") == KDLDocument([KDLNode("node")]))
    }

    @Test static func testNode() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        #expect(try parser.parse(#"node 1 2 "3" #true #false #null"#) == KDLDocument([KDLNode("node", arguments: [
            .int(1),
            .int(2),
            .string("3"),
            .bool(true),
            .bool(false),
            .null()
        ])]))
        #expect(try parser.parse("node { \n  node2\n}") == KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        #expect(try parser.parse("node { \n    node2   \n}") == KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        #expect(try parser.parse("node { node2; }") == KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        #expect(try parser.parse("node { node2 }") == KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        #expect(try parser.parse("node { node2; node3 }") == KDLDocument([KDLNode("node", children: [KDLNode("node2"), KDLNode("node3")])]))
    }

    @Test static func testNodeSlashdashComment() throws {
        let parser = KDLParser()
        #expect(try parser.parse("/-node") == KDLDocument([]))
        #expect(try parser.parse("/- node") == KDLDocument([]))
        #expect(try parser.parse("/- node\n") == KDLDocument([]))
        #expect(try parser.parse("/-node 1 2 3") == KDLDocument([]))
        #expect(try parser.parse("/-node key=#false") == KDLDocument([]))
        #expect(try parser.parse("/-node{\nnode\n}") == KDLDocument([]))
        #expect(try parser.parse("/-node 1 2 3 key=\"value\" \\\n{\nnode\n}") == KDLDocument([]))
    }

    @Test static func testArgSlashdashComment() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node /-1") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node /-1 2") == KDLDocument([KDLNode("node", arguments: [.int(2)])]))
        #expect(try parser.parse("node 1 /- 2 3") == KDLDocument([KDLNode("node", arguments: [.int(1), .int(3)])]))
        #expect(try parser.parse("node /--1") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node /- -1") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node \\\n/- -1") == KDLDocument([KDLNode("node")]))
    }

    @Test static func testPropSlashdashComment() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node /-key=1") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node /- key=1") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node key=1 /-key2=2") == KDLDocument([KDLNode("node", properties: ["key": .int(1)])]))
    }

    @Test static func testChildrenSlashdashComment() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node /-{}") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node /- {}") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node /-{\nnode2\n}") == KDLDocument([KDLNode("node")]))
    }

    @Test static func testString() throws {
        let parser = KDLParser()
        #expect(try parser.parse(#"node """#) == KDLDocument([KDLNode("node", arguments: [.string("")])]))
        #expect(try parser.parse(#"node "hello""#) == KDLDocument([KDLNode("node", arguments: [.string("hello")])]))
        #expect(try parser.parse(#"node "hello\nworld""#) == KDLDocument([KDLNode("node", arguments: [.string("hello\nworld")])]))
        #expect(try parser.parse(#"node -flag"#) == KDLDocument([KDLNode("node", arguments: [.string("-flag")])]))
        #expect(try parser.parse(#"node --flagg"#) == KDLDocument([KDLNode("node", arguments: [.string("--flagg")])]))
        #expect(try parser.parse(#"node "\u{10FFF}""#) == KDLDocument([KDLNode("node", arguments: [.string("\u{10FFF}")])]))
        #expect(try parser.parse(#"node "\"\\\b\f\n\r\t""#) == KDLDocument([KDLNode("node", arguments: [.string("\"\\\u{08}\u{0C}\n\r\t")])]))
        #expect(try parser.parse(#"node "\u{10}""#) == KDLDocument([KDLNode("node", arguments: [.string("\u{10}")])]))
        #expect(throws: (any Error).self) { try parser.parse(#"node "\i""#) }
        #expect(throws: (any Error).self) { try parser.parse(#"node "\u{c0ffee}""#) }
    }

    @Test static func testUnindentedMultilineStrings() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node \"\n  foo\n  bar\n    baz\n  qux\n  \"") == KDLDocument([KDLNode("node", arguments: [.string("foo\nbar\n  baz\nqux")])]))
        #expect(try parser.parse("node #\"\n  foo\n  bar\n    baz\n  qux\n  \"#") == KDLDocument([KDLNode("node", arguments: [.string("foo\nbar\n  baz\nqux")])]))
        #expect(throws: (any Error).self) { try parser.parse("node \"\n    foo\n  bar\n    baz\n    \"") }
        #expect(throws: (any Error).self) { try parser.parse("node #\"\n    foo\n  bar\n    baz\n    \"#") }
    }

    @Test static func testFloat() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 1.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0"))])]))
        #expect(try parser.parse("node 0.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("0.0"))])]))
        #expect(try parser.parse("node -1.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("-1.0"))])]))
        #expect(try parser.parse("node +1.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0"))])]))
        #expect(try parser.parse("node 1.0e10") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0e10"))])]))
        #expect(try parser.parse("node 1.0e-10") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0e-10"))])]))
        #expect(try parser.parse("node 123_456_789.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("123456789.0"))])]))
        #expect(try parser.parse("node 123_456_789.0_") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("123456789.0"))])]))
        #expect(throws: (any Error).self) { try parser.parse("node 1._0") }
        #expect(throws: (any Error).self) { try parser.parse("node 1.") }
        #expect(throws: (any Error).self) { try parser.parse("node 1.0v2") }
        #expect(throws: (any Error).self) { try parser.parse("node -1em") }
        #expect(throws: (any Error).self) { try parser.parse("node .0") }
    }

    @Test static func testInteger() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 0") == KDLDocument([KDLNode("node", arguments: [.int(0)])]))
        #expect(try parser.parse("node 0123456789") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        #expect(try parser.parse("node 0123_456_789") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        #expect(try parser.parse("node 0123_456_789_") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        #expect(try parser.parse("node +0123456789") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        #expect(try parser.parse("node -0123456789") == KDLDocument([KDLNode("node", arguments: [.int(-123456789)])]))
    }

    @Test static func testHexadecimal() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 0x0123456789abcdef") == KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        #expect(try parser.parse("node 0x01234567_89abcdef") == KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        #expect(try parser.parse("node 0x01234567_89abcdef_") == KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        #expect(throws: (any Error).self) { try parser.parse("node 0x_123") }
        #expect(throws: (any Error).self) { try parser.parse("node 0xg") }
        #expect(throws: (any Error).self) { try parser.parse("node 0xx") }
    }

    @Test static func testOctal() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 0o01234567") == KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        #expect(try parser.parse("node 0o0123_4567") == KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        #expect(try parser.parse("node 0o01234567_") == KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        #expect(throws: (any Error).self) { try parser.parse("node 0o_123") }
        #expect(throws: (any Error).self) { try parser.parse("node 0o8") }
        #expect(throws: (any Error).self) { try parser.parse("node 0oo") }
    }

    @Test static func testBinary() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 0b0101") == KDLDocument([KDLNode("node", arguments: [.int(5)])]))
        #expect(try parser.parse("node 0b01_10") == KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        #expect(try parser.parse("node 0b01___10") == KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        #expect(try parser.parse("node 0b0110_") == KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        #expect(throws: (any Error).self) { try parser.parse("node 0b_0110") }
        #expect(throws: (any Error).self) { try parser.parse("node 0b20") }
        #expect(throws: (any Error).self) { try parser.parse("node 0bb") }
    }

    @Test static func testRawstring() throws {
        let parser = KDLParser()
        #expect(try parser.parse(##"node #"foo"#"##) == KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        #expect(try parser.parse(##"node #"foo\nbar"#"##) == KDLDocument([KDLNode("node", arguments: [.string(#"foo\nbar"#)])]))
        #expect(try parser.parse(##"node #"foo"#"##) == KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        #expect(try parser.parse(###"node ##"foo"##"###) == KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        #expect(try parser.parse(##"node #"\nfoo\r"#"##) == KDLDocument([KDLNode("node", arguments: [.string(#"\nfoo\r"#)])]))
        #expect(throws: (any Error).self) { try parser.parse(###"node ##"foo"#"###) }
    }

    @Test static func testBoolean() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node #true") == KDLDocument([KDLNode("node", arguments: [.bool(true)])]))
        #expect(try parser.parse("node #false") == KDLDocument([KDLNode("node", arguments: [.bool(false)])]))
    }

    @Test static func testNull() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node #null") == KDLDocument([KDLNode("node", arguments: [.null()])]))
    }

    @Test static func testNodeSpace() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node 1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        #expect(try parser.parse("node\t1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        #expect(try parser.parse("node\t \\ // hello\n 1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
    }

    @Test static func testSingleLineComment() throws {
        let parser = KDLParser()
        #expect(try parser.parse("//hello") == KDLDocument([]))
        #expect(try parser.parse("// \thello") == KDLDocument([]))
        #expect(try parser.parse("//hello\n") == KDLDocument([]))
        #expect(try parser.parse("//hello\r\n") == KDLDocument([]))
        #expect(try parser.parse("//hello\n\r") == KDLDocument([]))
        #expect(try parser.parse("//hello\rworld") == KDLDocument([KDLNode("world")]))
        #expect(try parser.parse("//hello\nworld\r\n") == KDLDocument([KDLNode("world")]))
    }

    @Test static func testMultilineComment() throws {
        let parser = KDLParser()
        #expect(try parser.parse("/*hello*/") == KDLDocument([]))
        #expect(try parser.parse("/*hello*/\n") == KDLDocument([]))
        #expect(try parser.parse("/*\nhello\r\n*/") == KDLDocument([]))
        #expect(try parser.parse("/*\nhello** /\n*/") == KDLDocument([]))
        #expect(try parser.parse("/**\nhello** /\n*/") == KDLDocument([]))
        #expect(try parser.parse("/*hello*/world") == KDLDocument([KDLNode("world")]))
    }

    @Test static func testEscline() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node\\\n  1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        #expect(try parser.parse("node\\\n") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node\\ \n") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("node\\\n ") == KDLDocument([KDLNode("node")]))
    }

    @Test static func testWhitespace() throws {
        let parser = KDLParser()
        #expect(try parser.parse(" node") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("\tnode") == KDLDocument([KDLNode("node")]))
        #expect(try parser.parse("/* \nfoo\r\n */ etc") == KDLDocument([KDLNode("etc")]))
    }

    @Test static func testNewline() throws {
        let parser = KDLParser()
        #expect(try parser.parse("node1\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        #expect(try parser.parse("node1\rnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        #expect(try parser.parse("node1\r\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        #expect(try parser.parse("node1\n\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
    }

    @Test static func testBasic() throws {
        let parser = KDLParser()
        let doc = try parser.parse(#"title "Hello, World""#)
        let nodes = KDLDocument([
            KDLNode("title", arguments: [.string("Hello, World")]),
        ])
        #expect(doc == nodes)
    }

    @Test static func testMultipleValues() throws {
        let parser = KDLParser()
        let doc = try parser.parse("bookmarks 12 15 188 1234")
        let nodes = KDLDocument([
            KDLNode("bookmarks", arguments: [.int(12), .int(15), .int(188), .int(1234)]),
        ])
        #expect(doc == nodes)
    }

    @Test static func testProperties() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        author "Alex Monad" email="alex@example.com" active= #true
        foo bar =#true "baz" quux =\\
            #false 1 2 3
        """)
        let nodes = KDLDocument([
            KDLNode("author",
                arguments: [.string("Alex Monad")],
                properties: [
                    "email": .string("alex@example.com"),
                    "active": .bool(true),
                ]
            ),
            KDLNode("foo",
                arguments: [.string("baz"), .int(1), .int(2), .int(3)],
                properties: [
                    "bar": .bool(true),
                    "quux": .bool(false),
                ]
            )
        ])
        #expect(doc == nodes)
    }

    @Test static func testNestedChildNodes() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        contents {
            section "First section" {
                paragraph "This is the first paragraph"
                paragraph "This is the second paragraph"
            }
        }
        """)
        let nodes = KDLDocument([
            KDLNode("contents", children: [
                KDLNode("section", arguments: [.string("First section")], children: [
                    KDLNode("paragraph", arguments: [.string("This is the first paragraph")]),
                    KDLNode("paragraph", arguments: [.string("This is the second paragraph")]),
                ]),
            ]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testSemicolon() throws {
        let parser = KDLParser()
        let doc = try parser.parse("node1; node2; node3;")
        let nodes = KDLDocument([
            KDLNode("node1"),
            KDLNode("node2"),
            KDLNode("node3"),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testOptionalChildSemicolon() throws {
        let parser = KDLParser()
        let doc = try parser.parse("node {foo;bar;baz}")
        let nodes = KDLDocument([
            KDLNode("node", children: [
                KDLNode("foo"),
                KDLNode("bar"),
                KDLNode("baz"),
            ]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testRawstrings() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        node "this\\nhas\\tescapes"
        other #"C:\\Users\\zkat\\"#
        other-raw #"hello"world"#
        """)
        let nodes = KDLDocument([
            KDLNode("node", arguments: [.string("this\nhas\tescapes")]),
            KDLNode("other", arguments: [.string("C:\\Users\\zkat\\")]),
            KDLNode("other-raw", arguments: [.string("hello\"world")]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testMultilineStrings() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        string "my
        multiline
        value"
        """)
        let nodes = KDLDocument([
            KDLNode("string", arguments: [.string("my\nmultiline\nvalue")]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testNumbers() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        num 1.234e-42
        my-hex 0xdeadbeef
        my-octal 0o755
        my-binary 0b10101101
        bignum 1_000_000
        """)
        let nodes = KDLDocument([
            KDLNode("num", arguments: [.decimal(BigDecimal("1.234e-42"))]),
            KDLNode("my-hex", arguments: [.int(0xdeadbeef)]),
            KDLNode("my-octal", arguments: [.int(493)]),
            KDLNode("my-binary", arguments: [.int(173)]),
            KDLNode("bignum", arguments: [.int(1000000)]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testComments() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        // C style

        /*
        C style multiline
        */

        tag /*foo=#true*/ bar=#false

        /*/*
        hello
        */*/
        """)
        let nodes = KDLDocument([
            KDLNode("tag", properties: ["bar": .bool(false)])
        ]);
        #expect(doc == nodes)
    }

    @Test static func testSlashdash() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        /-mynode "foo" key=1 {
            a
            b
            c
        }

        mynode /- "commented" "not commented" /-key="value" /-{
            a
            b
        }
        """)
        let nodes = KDLDocument([
            KDLNode("mynode", arguments: [.string("not commented")]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testMultilineNodes() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        title \\
            "Some title"

        my-node 1 2 \\  // comments are ok after \\
                3 4
        """)
        let nodes = KDLDocument([
            KDLNode("title", arguments: [.string("Some title")]),
            KDLNode("my-node", arguments: [.int(1), .int(2), .int(3), .int(4)]),
        ]);
        #expect(doc == nodes)
    }

    @Test static func testUtf8() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        smile "😁"
        ノード お名前＝"☜(ﾟヮﾟ☜)"
        """)
        let nodes = KDLDocument([
            KDLNode("smile", arguments: [.string("😁")]),
            KDLNode("ノード", properties: ["お名前": .string("☜(ﾟヮﾟ☜)")])
        ])
        #expect(doc == nodes)
    }

    @Test static func testNodeNames() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        "!@$@$%Q$%~@!40" "1.2.3" "!!!!!"=#true
        foo123~!@$%^&*.:'|?+ "weeee"
        - 1
        """)
        let nodes = KDLDocument([
            KDLNode(##"!@$@$%Q$%~@!40"##, arguments: [.string("1.2.3")], properties: ["!!!!!": .bool(true)]),
            KDLNode(##"foo123~!@$%^&*.:'|?+"##, arguments: [.string("weeee")]),
            KDLNode("-", arguments: [.int(1)]),
        ])
        #expect(doc == nodes)
    }

    @Test static func testEscaping() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        node1 "\\u{1f600}"
        node2 "\\n\\t\\r\\\\\\"\\f\\b"
        """)
        let nodes = KDLDocument([
            KDLNode("node1", arguments: [.string("😀")]),
            KDLNode("node2", arguments: [.string("\n\t\r\\\"\u{0C}\u{08}")]),
        ])
        #expect(doc == nodes)
    }

    @Test static func testNodeType() throws {
        let parser = KDLParser()
        let doc = try parser.parse("(foo)node");
        let nodes = KDLDocument([
            KDLNode("node", type: "foo"),
        ])
        #expect(doc == nodes)
    }

    @Test static func testValueType() throws {
        let parser = KDLParser()
        let doc = try parser.parse(#"node (foo)"bar""#)
        let nodes = KDLDocument([
            KDLNode("node", arguments: [.string("bar", "foo")])
        ])
        #expect(doc == nodes)
    }

    @Test static func testPropertyType() throws {
        let parser = KDLParser()
        let doc = try parser.parse(#"node baz=(foo)"bar""#)
        let nodes = KDLDocument([
            KDLNode("node", properties: ["baz": .string("bar", "foo")]),
        ])
        #expect(doc == nodes)
    }

    @Test static func testChildType() throws {
        let parser = KDLParser()
        let doc = try parser.parse("""
        node {
            (foo)bar
        }
        """)
        let nodes = KDLDocument([
            KDLNode("node", children: [
                KDLNode("bar", type: "foo")
            ]),
        ])
        #expect(doc == nodes)
    }
}
