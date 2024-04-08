import XCTest
import BigDecimal
@testable import KDL

final class KDLNodeTests: XCTestCase {
    func testSubscript() throws {
        let node = KDLNode("node",
            arguments: [.int(1), .string("two")],
            properties: [ "three": .int(3), "four": .int(4) ]
        )

        XCTAssertEqual(node[0], .int(1))
        XCTAssertEqual(node[1], .string("two"))

        XCTAssertEqual(node["three"], .int(3))
        XCTAssertEqual(node["four"], .int(4))
        XCTAssertNil(node["five"])
    }

    func testChild() throws {
        let node = KDLNode("node", children: [
            KDLNode("foo"),
            KDLNode("bar")
        ])

        XCTAssertEqual(node.child(0), node.children[0])
        XCTAssertEqual(node.child(1), node.children[1])

        XCTAssertEqual(node.child("foo"), node.children[0])
        XCTAssertEqual(node.child("bar"), node.children[1])
        XCTAssertNil(node.child("baz"))
    }

    func testArg() throws {
        let node = KDLNode("node", children: [
            KDLNode("foo", arguments: [.string("bar")]),
            KDLNode("baz", arguments: [.string("qux")])
        ])

        XCTAssertEqual(node.arg(0), .string("bar"))
        XCTAssertEqual(node.arg("foo"), .string("bar"))
        XCTAssertEqual(node.arg(1), .string("qux"))
        XCTAssertEqual(node.arg("baz"), .string("qux"))
        XCTAssertNil(node.arg("norg"))
    }

    func testArgs() throws {
        let node = KDLNode("node", children: [
            KDLNode("foo", arguments: [.string("bar"), .string("baz")]),
            KDLNode("qux", arguments: [.string("norf")])
        ])

        XCTAssertEqual(node.args(0), [.string("bar"), .string("baz")])
        XCTAssertEqual(node.args("foo"), [.string("bar"), .string("baz")])
        XCTAssertEqual(node.args(1), [.string("norf")])
        XCTAssertEqual(node.args("qux"), [.string("norf")])
        XCTAssertNil(node.args("wat"))
    }

    func testDashVals() throws {
        let node = KDLNode("node", children: [
            KDLNode("node", children: [
                KDLNode("-", arguments: [.string("foo")]),
                KDLNode("-", arguments: [.string("bar")]),
                KDLNode("-", arguments: [.string("baz")])
            ])
        ])

        XCTAssertEqual(node.dashVals(0), [.string("foo"), .string("bar"), .string("baz")])
        XCTAssertEqual(node.dashVals("node"), [.string("foo"), .string("bar"), .string("baz")])
        XCTAssertNil(node.dashVals("qux"))
    }
}
