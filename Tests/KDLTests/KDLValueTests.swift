import XCTest
import BigDecimal
@testable import KDL

final class KDLValueTests: XCTestCase {
    func testDescription() throws {
        XCTAssertEqual(KDLValue.int(1).description, "1")
        XCTAssertEqual(KDLValue.int(1, "foo").description, "(foo)1")
        XCTAssertEqual(KDLValue.int(1, #"foo"bar"#).description, #"("foo\"bar")1"#)
        XCTAssertEqual(KDLValue.float(1.5).description, "1.5")
        XCTAssertEqual(KDLValue.decimal(BigDecimal("1.5E1000")).description, "1.5E+1000")
        XCTAssertEqual(KDLValue.decimal(BigDecimal("1.5E-1000")).description, "1.5E-1000")
        XCTAssertEqual(KDLValue.float(Float.infinity).description, "#inf")
        XCTAssertEqual(KDLValue.float(-Float.infinity).description, "#-inf")
        XCTAssertEqual(KDLValue.float(Float.nan).description, "#nan")
        XCTAssertEqual(KDLValue.bool(true).description, "#true")
        XCTAssertEqual(KDLValue.bool(false).description, "#false")
        XCTAssertEqual(KDLValue.null().description, "#null")
        XCTAssertEqual(KDLValue.string("foo").description, "foo")
        XCTAssertEqual(KDLValue.string(#"foo "bar" baz"#).description, "\"foo \\\"bar\\\" baz\"")
    }
}
