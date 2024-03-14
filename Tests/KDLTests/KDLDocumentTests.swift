import XCTest
import BigDecimal
@testable import KDL

final class KDLDocumentaTests: XCTestCase {
    func testSubscript() throws {
        let doc = KDLDocument([
            KDLNode("foo"),
            KDLNode("bar")
        ])

        XCTAssertEqual(doc[0], doc.nodes[0])
        XCTAssertEqual(doc[1], doc.nodes[1])

        XCTAssertEqual(doc["foo"], doc.nodes[0])
        XCTAssertEqual(doc["bar"], doc.nodes[1])

        XCTAssertNil(doc["baz"])
    }

    func testArg() throws {
        let doc = KDLDocument([
            KDLNode("foo", arguments: [.string("bar")]),
            KDLNode("baz", arguments: [.string("qux")])
        ])

        XCTAssertEqual(doc.arg(0), .string("bar"))
        XCTAssertEqual(doc.arg("foo"), .string("bar"))
        XCTAssertEqual(doc.arg(1), .string("qux"))
        XCTAssertEqual(doc.arg("baz"), .string("qux"))

        XCTAssertNil(doc.arg("norf"))
    }

    func testArgs() throws {
        let doc = KDLDocument([
            KDLNode("foo", arguments: [.string("bar"), .string("baz")]),
            KDLNode("qux", arguments: [.string("norf")])
        ])

        XCTAssertEqual(doc.args(0), [.string("bar"), .string("baz")])
        XCTAssertEqual(doc.args("foo"), [.string("bar"), .string("baz")])
        XCTAssertEqual(doc.args(1), [.string("norf")])
        XCTAssertEqual(doc.args("qux"), [.string("norf")])
        XCTAssertNil(doc.args("wat"))
    }

    func testDashVals() throws {
        let doc = KDLDocument([
            KDLNode("node", children: [
                KDLNode("-", arguments: [.string("foo")]),
                KDLNode("-", arguments: [.string("bar")]),
                KDLNode("-", arguments: [.string("baz")])
            ])
        ])

        XCTAssertEqual(doc.dashVals(0), [.string("foo"), .string("bar"), .string("baz")])
        XCTAssertEqual(doc.dashVals("node"), [.string("foo"), .string("bar"), .string("baz")])
        XCTAssertNil(doc.dashVals("asdf"))
    }
}