import Foundation
import BigDecimal
import Testing
@testable import KDL

@Suite("Parser tests")
struct KDLParserV1Tests {
    @Test static func testParseEmptyString() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("") == KDLDocument([]))
        try #expect(parser.parse(" ") == KDLDocument([]))
        try #expect(parser.parse("\n") == KDLDocument([]))
    }

    @Test static func testNodes() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node\n") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("\nnode") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node1\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
    }

    @Test static func testNode() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node;") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node 1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        try #expect(parser.parse(#"node 1 2 "3" true false null"#) == KDLDocument([KDLNode("node", arguments: [
            .int(1),
            .int(2),
            .string("3"),
            .bool(true),
            .bool(false),
            .null()
        ])]))
        try #expect(parser.parse("node { \n  node2\n}") == KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
        try #expect(parser.parse("node { node2; }") == KDLDocument([KDLNode("node", children: [KDLNode("node2")])]))
    }

    @Test static func testNodeSlashdashComment() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("/-node") == KDLDocument([]))
        try #expect(parser.parse("/- node") == KDLDocument([]))
        try #expect(parser.parse("/- node\n") == KDLDocument([]))
        try #expect(parser.parse("/-node 1 2 3") == KDLDocument([]))
        try #expect(parser.parse("/-node key=false") == KDLDocument([]))
        try #expect(parser.parse("/-node{\nnode\n}") == KDLDocument([]))
        try #expect(parser.parse("/-node 1 2 3 key=\"value\" \\\n{\nnode\n}") == KDLDocument([]))
    }

    @Test static func testArgSlashdashComment() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node /-1") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node /-1 2") == KDLDocument([KDLNode("node", arguments: [.int(2)])]))
        try #expect(parser.parse("node 1 /- 2 3") == KDLDocument([KDLNode("node", arguments: [.int(1), .int(3)])]))
        try #expect(parser.parse("node /--1") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node /- -1") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node \\\n/- -1") == KDLDocument([KDLNode("node")]))
    }

    @Test static func testPropSlashdashComment() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node /-key=1") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node /- key=1") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node key=1 /-key2=2") == KDLDocument([KDLNode("node", properties: ["key": .int(1)])]))
    }

    @Test static func testChildrenSlashdashComment() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node /-{}") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node /- {}") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("node /-{\nnode2\n}") == KDLDocument([KDLNode("node")]))
    }

    @Test static func testString() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse(#"node """#) == KDLDocument([KDLNode("node", arguments: [.string("")])]))
        try #expect(parser.parse(#"node "hello""#) == KDLDocument([KDLNode("node", arguments: [.string("hello")])]))
        try #expect(parser.parse(#"node "hello\nworld""#) == KDLDocument([KDLNode("node", arguments: [.string("hello\nworld")])]))
        try #expect(parser.parse(#"node "\u{10FFF}""#) == KDLDocument([KDLNode("node", arguments: [.string("\u{10FFF}")])]))
        try #expect(parser.parse(#"node "\"\\\b\f\n\r\t""#) == KDLDocument([KDLNode("node", arguments: [.string("\"\\\u{08}\u{0C}\n\r\t")])]))
        try #expect(parser.parse(#"node "\u{10}""#) == KDLDocument([KDLNode("node", arguments: [.string("\u{10}")])]))
        #expect(throws: (any Error).self) { try parser.parse(#"node "\i""#) }
        #expect(throws: (any Error).self) { try parser.parse(#"node "\u{c0ffee}""#) }
        #expect(throws: (any Error).self) { try parser.parse(#"node "oops"#) }
    }

    @Test static func testFloat() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node 1.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0"))])]))
        try #expect(parser.parse("node 0.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("0.0"))])]))
        try #expect(parser.parse("node -1.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("-1.0"))])]))
        try #expect(parser.parse("node +1.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0"))])]))
        try #expect(parser.parse("node 1.0e10") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0e10"))])]))
        try #expect(parser.parse("node 1.0e-10") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("1.0e-10"))])]))
        try #expect(parser.parse("node 123_456_789.0") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("123456789.0"))])]))
        try #expect(parser.parse("node 123_456_789.0_") == KDLDocument([KDLNode("node", arguments: [.decimal(BigDecimal("123456789.0"))])]))
        #expect(throws: (any Error).self) { try parser.parse("node ?1.0") }
        #expect(throws: (any Error).self) { try parser.parse("node _1.0") }
        #expect(throws: (any Error).self) { try parser.parse("node 1._0") }
        #expect(throws: (any Error).self) { try parser.parse("node 1.") }
        #expect(throws: (any Error).self) { try parser.parse("node .0") }
    }

    @Test static func testInteger() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node 0") == KDLDocument([KDLNode("node", arguments: [.int(0)])]))
        try #expect(parser.parse("node 0123456789") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        try #expect(parser.parse("node 0123_456_789") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        try #expect(parser.parse("node 0123_456_789_") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        try #expect(parser.parse("node +0123456789") == KDLDocument([KDLNode("node", arguments: [.int(123456789)])]))
        try #expect(parser.parse("node -0123456789") == KDLDocument([KDLNode("node", arguments: [.int(-123456789)])]))
        #expect(throws: (any Error).self) { try parser.parse("node ?0123456789") }
        #expect(throws: (any Error).self) { try parser.parse("node _0123456789") }
        #expect(throws: (any Error).self) { try parser.parse("node a") }
        #expect(throws: (any Error).self) { try parser.parse("node --") }
    }

    @Test static func testHexadecimal() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node 0x0123456789abcdef") == KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        try #expect(parser.parse("node 0x01234567_89abcdef") == KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        try #expect(parser.parse("node 0x01234567_89abcdef_") == KDLDocument([KDLNode("node", arguments: [.int(0x0123456789abcdef)])]))
        #expect(throws: (any Error).self) { try parser.parse("node 0x_123") }
        #expect(throws: (any Error).self) { try parser.parse("node 0xg") }
        #expect(throws: (any Error).self) { try parser.parse("node 0xx") }
    }

    @Test static func testOctal() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node 0o01234567") == KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        try #expect(parser.parse("node 0o0123_4567") == KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        try #expect(parser.parse("node 0o01234567_") == KDLDocument([KDLNode("node", arguments: [.int(342391)])]))
        #expect(throws: (any Error).self) { try parser.parse("node 0o_123") }
        #expect(throws: (any Error).self) { try parser.parse("node 0o8") }
        #expect(throws: (any Error).self) { try parser.parse("node 0oo") }
    }

    @Test static func testBinary() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node 0b0101") == KDLDocument([KDLNode("node", arguments: [.int(5)])]))
        try #expect(parser.parse("node 0b01_10") == KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        try #expect(parser.parse("node 0b01___10") == KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        try #expect(parser.parse("node 0b0110_") == KDLDocument([KDLNode("node", arguments: [.int(6)])]))
        #expect(throws: (any Error).self) { try parser.parse("node 0b_0110") }
        #expect(throws: (any Error).self) { try parser.parse("node 0b20") }
        #expect(throws: (any Error).self) { try parser.parse("node 0bb") }
    }

    @Test static func testRawstring() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse(#"node r"foo""#) == KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        try #expect(parser.parse(#"node r"foo\nbar""#) == KDLDocument([KDLNode("node", arguments: [.string(#"foo\nbar"#)])]))
        try #expect(parser.parse(##"node r#"foo"#"##) == KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        try #expect(parser.parse(###"node r##"foo"##"###) == KDLDocument([KDLNode("node", arguments: [.string("foo")])]))
        try #expect(parser.parse(#"node r"\nfoo\r""#) == KDLDocument([KDLNode("node", arguments: [.string(#"\nfoo\r"#)])]))
        #expect(throws: (any Error).self) { try parser.parse(###"node r##"foo"#"###) }
    }

    @Test static func testBoolean() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node true") == KDLDocument([KDLNode("node", arguments: [.bool(true)])]))
        try #expect(parser.parse("node false") == KDLDocument([KDLNode("node", arguments: [.bool(false)])]))
    }

    @Test static func testNull() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node null") == KDLDocument([KDLNode("node", arguments: [.null()])]))
    }

    @Test static func testNodeSpace() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node 1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        try #expect(parser.parse("node\t1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        try #expect(parser.parse("node\t \\ // hello\n 1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
    }

    @Test static func testSingleLineComment() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("//hello") == KDLDocument([]))
        try #expect(parser.parse("// \thello") == KDLDocument([]))
        try #expect(parser.parse("//hello\n") == KDLDocument([]))
        try #expect(parser.parse("//hello\r\n") == KDLDocument([]))
        try #expect(parser.parse("//hello\n\r") == KDLDocument([]))
        try #expect(parser.parse("//hello\rworld") == KDLDocument([KDLNode("world")]))
        try #expect(parser.parse("//hello\nworld\r\n") == KDLDocument([KDLNode("world")]))
    }

    @Test static func testMultilineComment() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("/*hello*/") == KDLDocument([]))
        try #expect(parser.parse("/*hello*/\n") == KDLDocument([]))
        try #expect(parser.parse("/*\nhello\r\n*/") == KDLDocument([]))
        try #expect(parser.parse("/*\nhello** /\n*/") == KDLDocument([]))
        try #expect(parser.parse("/**\nhello** /\n*/") == KDLDocument([]))
        try #expect(parser.parse("/*hello*/world") == KDLDocument([KDLNode("world")]))
    }

    @Test static func testEscline() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node\\\n  1") == KDLDocument([KDLNode("node", arguments: [.int(1)])]))
        #expect(throws: (any Error).self) { try parser.parse("node\\\nnode2") }
    }

    @Test static func testWhitespace() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse(" node") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("\tnode") == KDLDocument([KDLNode("node")]))
        try #expect(parser.parse("/* \nfoo\r\n */ etc") == KDLDocument([KDLNode("etc")]))
    }

    @Test static func testNewline() throws {
        let parser = KDLParserV1(outputVersion: 2)
        try #expect(parser.parse("node1\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        try #expect(parser.parse("node1\rnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        try #expect(parser.parse("node1\r\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
        try #expect(parser.parse("node1\n\nnode2") == KDLDocument([KDLNode("node1"), KDLNode("node2")]))
    }

    @Test static func testComments() throws {
        let parser = KDLParserV1(outputVersion: 2)
        let doc = try parser.parse("""
        // C style

        /*
        C style multiline
        */

        tag /*foo=true*/ bar=false

        /*/*
        hello
        */*/
        """)
        let nodes = KDLDocument([
            KDLNode("tag", properties: ["bar": .bool(false)])
        ]);
        #expect(doc == nodes)
    }

    @Test static func testUtf8() throws {
        let parser = KDLParserV1(outputVersion: 2)
        let doc = try parser.parse("""
        smile "😁"
        ノード お名前="☜(ﾟヮﾟ☜)"
        """)
        let nodes = KDLDocument([
            KDLNode("smile", arguments: [.string("😁")]),
            KDLNode("ノード", properties: ["お名前": .string("☜(ﾟヮﾟ☜)")])
        ])
        #expect(doc == nodes)
    }

    @Test static func testNodeNames() throws {
        let parser = KDLParserV1(outputVersion: 2)
        let doc = try parser.parse("""
          "!@#$@$%Q#$%~@!40" "1.2.3" "!!!!!"=true
          foo123~!@#$%^&*.:'|?+ "weeee"
        """)
        let nodes = KDLDocument([
            KDLNode(##"!@#$@$%Q#$%~@!40"##, arguments: [.string("1.2.3")], properties: ["!!!!!": .bool(true)]),
            KDLNode(##"foo123~!@#$%^&*.:'|?+"##, arguments: [.string("weeee")])
        ])
        #expect(doc == nodes)
    }

    @Test static func testVersionDirective() throws {
        let parser = KDLParserV1(outputVersion: 2)
        #expect(throws: Never.self) { try parser.parse("/- kdl-version 1\nnode \"foo\"") }

        #expect(throws: (any Error).self) { try parser.parse("/- kdl-version 2\nnode foo") }
    }
}
