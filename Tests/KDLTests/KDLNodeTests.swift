import Testing
import BigDecimal
@testable import KDL

@Suite("Node tests")
struct KDLNodeTests {
    @Test static func testSubscript() throws {
        let node = KDLNode("node",
            arguments: [.int(1), .string("two")],
            properties: [ "three": .int(3), "four": .int(4) ]
        )

        #expect(node[0] == .int(1))
        #expect(node[1] == .string("two"))

        #expect(node["three"] == .int(3))
        #expect(node["four"] == .int(4))
        #expect(node["five"] == nil)
    }

    @Test static func testChild() throws {
        let node = KDLNode("node", children: [
            KDLNode("foo"),
            KDLNode("bar")
        ])

        #expect(node.child(0) == node.children[0])
        #expect(node.child(1) == node.children[1])

        #expect(node.child("foo") == node.children[0])
        #expect(node.child("bar") == node.children[1])
        #expect(node.child("baz") == nil)
    }

    @Test static func testArg() throws {
        let node = KDLNode("node", children: [
            KDLNode("foo", arguments: [.string("bar")]),
            KDLNode("baz", arguments: [.string("qux")])
        ])

        #expect(node.arg(0) == .string("bar"))
        #expect(node.arg("foo") == .string("bar"))
        #expect(node.arg(1) == .string("qux"))
        #expect(node.arg("baz") == .string("qux"))
        #expect(node.arg("norg") == nil)
    }

    @Test static func testArgs() throws {
        let node = KDLNode("node", children: [
            KDLNode("foo", arguments: [.string("bar"), .string("baz")]),
            KDLNode("qux", arguments: [.string("norf")])
        ])

        #expect(node.args(0) == [.string("bar"), .string("baz")])
        #expect(node.args("foo") == [.string("bar"), .string("baz")])
        #expect(node.args(1) == [.string("norf")])
        #expect(node.args("qux") == [.string("norf")])
        #expect(node.args("wat") == nil)
    }

    @Test static func testDashVals() throws {
        let node = KDLNode("node", children: [
            KDLNode("node", children: [
                KDLNode("-", arguments: [.string("foo")]),
                KDLNode("-", arguments: [.string("bar")]),
                KDLNode("-", arguments: [.string("baz")])
            ])
        ])

        #expect(node.dashVals(0) == [.string("foo"), .string("bar"), .string("baz")])
        #expect(node.dashVals("node") == [.string("foo"), .string("bar"), .string("baz")])
        #expect(node.dashVals("qux") == nil)
    }
}
