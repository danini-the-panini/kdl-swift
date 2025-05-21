import Testing
import BigDecimal
@testable import KDL

@Suite("Value tests")
final class KDLValueTests {
    @Test func testDescription() throws {
        #expect(KDLValue.int(1).description == "1")
        #expect(KDLValue.int(1, "foo").description == "(foo)1")
        #expect(KDLValue.int(1, #"foo"bar"#).description == #"("foo\"bar")1"#)
        #expect(KDLValue.float(1.5).description == "1.5")
        #expect(KDLValue.decimal(BigDecimal("1.5E1000")).description == "1.5E+1000")
        #expect(KDLValue.decimal(BigDecimal("1.5E-1000")).description == "1.5E-1000")
        #expect(KDLValue.float(Float.infinity).description == "#inf")
        #expect(KDLValue.float(-Float.infinity).description == "#-inf")
        #expect(KDLValue.float(Float.nan).description == "#nan")
        #expect(KDLValue.bool(true).description == "#true")
        #expect(KDLValue.bool(false).description == "#false")
        #expect(KDLValue.null().description == "#null")
        #expect(KDLValue.string("foo").description == "foo")
        #expect(KDLValue.string(#"foo "bar" baz"#).description == "\"foo \\\"bar\\\" baz\"")
    }
}
