import Testing
import BigDecimal
@testable import KDL

@Suite("Document tests")
struct KDLDocumentTests {
    @Test static func testSubscript() throws {
        let doc = KDLDocument([
            KDLNode("foo"),
            KDLNode("bar")
        ])

        #expect(doc[0] == doc.nodes[0])
        #expect(doc[1] == doc.nodes[1])

        #expect(doc["foo"] == doc.nodes[0])
        #expect(doc["bar"] == doc.nodes[1])

        #expect(doc["baz"] == nil)
    }

    @Test static func testArg() throws {
        let doc = KDLDocument([
            KDLNode("foo", arguments: [.string("bar")]),
            KDLNode("baz", arguments: [.string("qux")])
        ])

        #expect(doc.arg(0) == .string("bar"))
        #expect(doc.arg("foo") == .string("bar"))
        #expect(doc.arg(1) == .string("qux"))
        #expect(doc.arg("baz") == .string("qux"))

        #expect(doc.arg("norf") == nil)
    }

    @Test static func testArgs() throws {
        let doc = KDLDocument([
            KDLNode("foo", arguments: [.string("bar"), .string("baz")]),
            KDLNode("qux", arguments: [.string("norf")])
        ])

        #expect(doc.args(0) == [.string("bar"), .string("baz")])
        #expect(doc.args("foo") == [.string("bar"), .string("baz")])
        #expect(doc.args(1) == [.string("norf")])
        #expect(doc.args("qux") == [.string("norf")])
        #expect(doc.args("wat") == nil)
    }

    @Test static func testDashVals() throws {
        let doc = KDLDocument([
            KDLNode("node", children: [
                KDLNode("-", arguments: [.string("foo")]),
                KDLNode("-", arguments: [.string("bar")]),
                KDLNode("-", arguments: [.string("baz")])
            ])
        ])

        #expect(doc.dashVals(0) == [.string("foo"), .string("bar"), .string("baz")])
        #expect(doc.dashVals("node") == [.string("foo"), .string("bar"), .string("baz")])
        #expect(doc.dashVals("asdf") == nil)
    }
}
