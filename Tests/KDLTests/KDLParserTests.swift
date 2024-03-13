import Foundation
import XCTest
@testable import KDL

final class KDLParserTests: XCTestCase {
    lazy var parser: KDLParser = {
        return KDLParser()
    }()

    func testParseEmptyString() throws {
        XCTAssertEqual(try parser.parse(""), KDLDocument([]))
        XCTAssertEqual(try parser.parse(" "), KDLDocument([]))
        XCTAssertEqual(try parser.parse("\n"), KDLDocument([]))
    }

    func testNodes() throws {
        XCTAssertEqual(try parser.parse("node"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node\n"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("\nnode"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node1\nnode2"), KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        XCTAssertEqual(try parser.parse("node;"), KDLDocument([KDLNode("node")]))
    }

    func testNode() throws {
        XCTAssertEqual(try parser.parse("node 1"), KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        XCTAssertEqual(try parser.parse(#"node 1 2 "3" #true #false #null"#), KDLDocument([KDLNode("node", arguments: [
            .int(1),
            .int(2),
            .string("3"),
            .bool(true),
            .bool(false),
            .null()
        ])]))
        XCTAssertEqual(try parser.parse("node { \n  node2\n}"), KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        XCTAssertEqual(try parser.parse("node { \n    node2   \n}"), KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        XCTAssertEqual(try parser.parse("node { node2; }"), KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        XCTAssertEqual(try parser.parse("node { node2 }"), KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        XCTAssertEqual(try parser.parse("node { node2; node3 }"), KDLDocument([KDLNode("node", children: [KDLNode("node2"), KDLNode("node3")])]))
    }

    func testNodeSlashdashComment() throws {
        XCTAssertEqual(try parser.parse("/-node"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/- node"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/- node\n"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/-node 1 2 3"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/-node key=#false"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/-node{\nnode\n}"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/-node 1 2 3 key=\"value\" \\\n{\nnode\n}"), KDLDocument([]))
    }

    func testArgSlashdashComment() throws {
        XCTAssertEqual(try parser.parse("node /-1"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node /-1 2"), KDLDocument([KDLNode("node", arguments: [.int(2)])]))
        XCTAssertEqual(try parser.parse("node 1 /- 2 3"), KDLDocument([KDLNode("node", arguments: [.int(1), .int(3)])]))
        XCTAssertEqual(try parser.parse("node /--1"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node /- -1"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node \\\n/- -1"), KDLDocument([KDLNode("node")]))
    }

    func testPropSlashdashComment() throws {
        XCTAssertEqual(try parser.parse("node /-key=1"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node /- key=1"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node key=1 /-key2=2"), KDLDocument([KDLNode("node", properties: ["key": .int(1)])]))
    }

    func testChildrenSlashdashComment() throws {
        XCTAssertEqual(try parser.parse("node /-{}"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node /- {}"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node /-{\nnode2\n}"), KDLDocument([KDLNode("node")]))
    }

    func testString() throws {
        XCTAssertEqual(try parser.parse(#"node """#), KDLDocument([KDLNode("node", arguments: [.string("")])]))
        XCTAssertEqual(try parser.parse(#"node "hello""#), KDLDocument([KDLNode("node", arguments: [.string("hello")])]))
        XCTAssertEqual(try parser.parse(#"node "hello\nworld""#), KDLDocument([KDLNode("node", arguments: [.string("hello\nworld")])]))
        XCTAssertEqual(try parser.parse(#"node -flag"#), KDLDocument([KDLNode("node", arguments: [.string("-flag")])]))
        XCTAssertEqual(try parser.parse(#"node --flagg"#), KDLDocument([KDLNode("node", arguments: [.string("--flagg")])]))
        XCTAssertEqual(try parser.parse(#"node "\u{10FFF}""#), KDLDocument([KDLNode("node", arguments: [.string("\u{10FFF}")])]))
        XCTAssertEqual(try parser.parse(#"node "\"\\\b\f\n\r\t""#), KDLDocument([KDLNode("node", arguments: [.string("\"\\\u{08}\u{0C}\n\r\t")])]))
        XCTAssertEqual(try parser.parse(#"node "\u{10}""#), KDLDocument([KDLNode("node", arguments: [.string("\u{10}")])]))
        XCTAssertThrowsError(try parser.parse(#"node "\i""#))
        XCTAssertThrowsError(try parser.parse(#"node "\u{c0ffee}""#))
    }

    func testUnindentedMultilineStrings() throws {
        XCTAssertEqual(try parser.parse("node \"\n  foo\n  bar\n    baz\n  qux\n  \""), KDLDocument([KDLNode("node", arguments: [.string("foo\nbar\n  baz\nqux")])]))
        XCTAssertEqual(try parser.parse("node #\"\n  foo\n  bar\n    baz\n  qux\n  \"#"), KDLDocument([KDLNode("node", arguments: [.string("foo\nbar\n  baz\nqux")])]))
        XCTAssertThrowsError(try parser.parse("node \"\n    foo\n  bar\n    baz\n    \""))
        XCTAssertThrowsError(try parser.parse("node #\"\n    foo\n  bar\n    baz\n    \"#"))
    }

    func testFloat() throws {
        XCTAssertEqual(try parser.parse("node 1.0"), KDLDocument([KDLNode("node", arguments: [.decimal(1.0)])]))
        XCTAssertEqual(try parser.parse("node 0.0"), KDLDocument([KDLNode("node", arguments: [.decimal(0.0)])]))
        XCTAssertEqual(try parser.parse("node -1.0"), KDLDocument([KDLNode("node", arguments: [.decimal(-1.0)])]))
        XCTAssertEqual(try parser.parse("node +1.0"), KDLDocument([KDLNode("node", arguments: [.decimal(1.0)])]))
        XCTAssertEqual(try parser.parse("node 1.0e10"), KDLDocument([KDLNode("node", arguments: [.decimal(1.0e10)])]))
        XCTAssertEqual(try parser.parse("node 1.0e-10"), KDLDocument([KDLNode("node", arguments: [.decimal(1.0e-10)])]))
        XCTAssertEqual(try parser.parse("node 123_456_789.0"), KDLDocument([KDLNode("node", arguments: [.decimal(123456789.0)])]))
        XCTAssertEqual(try parser.parse("node 123_456_789.0_"), KDLDocument([KDLNode("node", arguments: [.decimal(123456789.0)])]))
        XCTAssertThrowsError(try parser.parse("node 1._0"))
        XCTAssertThrowsError(try parser.parse("node 1."))
        XCTAssertThrowsError(try parser.parse("node 1.0v2"))
        XCTAssertThrowsError(try parser.parse("node -1em"))
        XCTAssertThrowsError(try parser.parse("node .0"))
    }

    func testInteger() throws {
        XCTAssertEqual(try parser.parse("node 0"), KDLDocument([KDLNode("node", arguments: [.int(0)])]))
        XCTAssertEqual(try parser.parse("node 0123456789"), KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        XCTAssertEqual(try parser.parse("node 0123_456_789"), KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        XCTAssertEqual(try parser.parse("node 0123_456_789_"), KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        XCTAssertEqual(try parser.parse("node +0123456789"), KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        XCTAssertEqual(try parser.parse("node -0123456789"), KDLDocument([KDLNode("node", arguments: [.int(-123456789)])]))
    }

    func testHexadecimal() throws {
        XCTAssertEqual(try parser.parse("node 0x0123456789abcdef"), KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        XCTAssertEqual(try parser.parse("node 0x01234567_89abcdef"), KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        XCTAssertEqual(try parser.parse("node 0x01234567_89abcdef_"), KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        XCTAssertThrowsError(try parser.parse("node 0x_123"))
        XCTAssertThrowsError(try parser.parse("node 0xg"))
        XCTAssertThrowsError(try parser.parse("node 0xx"))
    }

    func testOctal() throws {
        XCTAssertEqual(try parser.parse("node 0o01234567"), KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        XCTAssertEqual(try parser.parse("node 0o0123_4567"), KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        XCTAssertEqual(try parser.parse("node 0o01234567_"), KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        XCTAssertThrowsError(try parser.parse("node 0o_123"))
        XCTAssertThrowsError(try parser.parse("node 0o8"))
        XCTAssertThrowsError(try parser.parse("node 0oo"))
    }

    func testBinary() throws {
        XCTAssertEqual(try parser.parse("node 0b0101"), KDLDocument([KDLNode("node", arguments: [.int(5)])]))
        XCTAssertEqual(try parser.parse("node 0b01_10"), KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        XCTAssertEqual(try parser.parse("node 0b01___10"), KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        XCTAssertEqual(try parser.parse("node 0b0110_"), KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        XCTAssertThrowsError(try parser.parse("node 0b_0110"))
        XCTAssertThrowsError(try parser.parse("node 0b20"))
        XCTAssertThrowsError(try parser.parse("node 0bb"))
    }

    func testRawstring() throws {
        XCTAssertEqual(try parser.parse(##"node #"foo"#"##), KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        XCTAssertEqual(try parser.parse(##"node #"foo\nbar"#"##), KDLDocument([KDLNode("node", arguments: [.string(#"foo\nbar"#)])]))
        XCTAssertEqual(try parser.parse(##"node #"foo"#"##), KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        XCTAssertEqual(try parser.parse(###"node ##"foo"##"###), KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        XCTAssertEqual(try parser.parse(##"node #"\nfoo\r"#"##), KDLDocument([KDLNode("node", arguments: [.string(#"\nfoo\r"#)])]))
        XCTAssertThrowsError(try parser.parse(###"node ##"foo"#"###))
    }

    func testBoolean() throws {
        XCTAssertEqual(try parser.parse("node #true"), KDLDocument([KDLNode("node", arguments: [.bool(true)])]))
        XCTAssertEqual(try parser.parse("node #false"), KDLDocument([KDLNode("node", arguments: [.bool(false)])]))
    }

    func testNull() throws {
        XCTAssertEqual(try parser.parse("node #null"), KDLDocument([KDLNode("node", arguments: [.null()])]))
    }

    func testNodeSpace() throws {
        XCTAssertEqual(try parser.parse("node 1"), KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        XCTAssertEqual(try parser.parse("node\t1"), KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        XCTAssertEqual(try parser.parse("node\t \\ // hello\n 1"), KDLDocument([KDLNode("node", arguments: [.int(1)])]))
    }

    func testSingleLineComment() throws {
        XCTAssertEqual(try parser.parse("//hello"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("// \thello"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("//hello\n"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("//hello\r\n"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("//hello\n\r"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("//hello\rworld"), KDLDocument([KDLNode("world")]))
        XCTAssertEqual(try parser.parse("//hello\nworld\r\n"), KDLDocument([KDLNode("world")]))
    }

    func testMultilineComment() throws {
        XCTAssertEqual(try parser.parse("/*hello*/"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/*hello*/\n"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/*\nhello\r\n*/"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/*\nhello** /\n*/"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/**\nhello** /\n*/"), KDLDocument([]))
        XCTAssertEqual(try parser.parse("/*hello*/world"), KDLDocument([KDLNode("world")]))
    }

    func testEscline() throws {
        XCTAssertEqual(try parser.parse("node\\\n  1"), KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        XCTAssertEqual(try parser.parse("node\\\n"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node\\ \n"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("node\\\n "), KDLDocument([KDLNode("node")]))
    }

    func testWhitespace() throws {
        XCTAssertEqual(try parser.parse(" node"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("\tnode"), KDLDocument([KDLNode("node")]))
        XCTAssertEqual(try parser.parse("/* \nfoo\r\n */ etc"), KDLDocument([KDLNode("etc")]))
    }

    func testNewline() throws {
        XCTAssertEqual(try parser.parse("node1\nnode2"), KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        XCTAssertEqual(try parser.parse("node1\rnode2"), KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        XCTAssertEqual(try parser.parse("node1\r\nnode2"), KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        XCTAssertEqual(try parser.parse("node1\n\nnode2"), KDLDocument([KDLNode("node1"), KDLNode("node2")]))
    }

    func testBasic() throws {
        let doc = try parser.parse(#"title "Hello, World""#)
        let nodes = KDLDocument([
            KDLNode("title", arguments: [.string("Hello, World")]),
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testMultipleValues() throws {
        let doc = try parser.parse("bookmarks 12 15 188 1234")
        let nodes = KDLDocument([
            KDLNode("bookmarks", arguments: [.int(12), .int(15), .int(188), .int(1234)]),
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testProperties() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testNestedChildNodes() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testSemicolon() throws {
        let doc = try parser.parse("node1; node2; node3;")
        let nodes = KDLDocument([
            KDLNode("node1"),
            KDLNode("node2"),
            KDLNode("node3"),
        ]);
        XCTAssertEqual(doc, nodes)
    }

    func testOptionalChildSemicolon() throws {
        let doc = try parser.parse("node {foo;bar;baz}")
        let nodes = KDLDocument([
            KDLNode("node", children: [
                KDLNode("foo"),
                KDLNode("bar"),
                KDLNode("baz"),
            ]),
        ]);
        XCTAssertEqual(doc, nodes)
    }

    func testRawstrings() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testMultilineStrings() throws {
        let doc = try parser.parse("""
        string "my
        multiline
        value"
        """)
        let nodes = KDLDocument([
            KDLNode("string", arguments: [.string("my\nmultiline\nvalue")]),
        ]);
        XCTAssertEqual(doc, nodes)
    }

    func testNumbers() throws {
        let doc = try parser.parse("""
        num 1.234e-42
        my-hex 0xdeadbeef
        my-octal 0o755
        my-binary 0b10101101
        bignum 1_000_000
        """)
        let nodes = KDLDocument([
            KDLNode("num", arguments: [.decimal(Decimal(string: "1.234e-42")!)]),
            KDLNode("my-hex", arguments: [.int(0xdeadbeef)]),
            KDLNode("my-octal", arguments: [.int(493)]),
            KDLNode("my-binary", arguments: [.int(173)]),
            KDLNode("bignum", arguments: [.int(1000000)]),
        ]);
        XCTAssertEqual(doc, nodes)
    }

    func testComments() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testSlashdash() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testMultilineNodes() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testUtf8() throws {
        let doc = try parser.parse("""
        smile "😁"
        ノード お名前＝"☜(ﾟヮﾟ☜)"
        """)
        let nodes = KDLDocument([
            KDLNode("smile", arguments: [.string("😁")]),
            KDLNode("ノード", properties: ["お名前": .string("☜(ﾟヮﾟ☜)")])
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testNodeNames() throws {
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
        XCTAssertEqual(doc, nodes)
    }

    func testEscaping() throws {
        let doc = try parser.parse("""
        node1 "\\u{1f600}"
        node2 "\\n\\t\\r\\\\\\"\\f\\b"
        """)
        let nodes = KDLDocument([
            KDLNode("node1", arguments: [.string("😀")]),
            KDLNode("node2", arguments: [.string("\n\t\r\\\"\u{0C}\u{08}")]),
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testNodeType() throws {
        let doc = try parser.parse("(foo)node");
        let nodes = KDLDocument([
            KDLNode("node", type: "foo"),
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testValueType() throws {
        let doc = try parser.parse(#"node (foo)"bar""#)
        let nodes = KDLDocument([
            KDLNode("node", arguments: [.string("bar", "foo")])
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testPropertyType() throws {
        let doc = try parser.parse(#"node baz=(foo)"bar""#)
        let nodes = KDLDocument([
            KDLNode("node", properties: ["baz": .string("bar", "foo")]),
        ])
        XCTAssertEqual(doc, nodes)
    }

    func testChildType() throws {
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
        XCTAssertEqual(doc, nodes)
    }
}
