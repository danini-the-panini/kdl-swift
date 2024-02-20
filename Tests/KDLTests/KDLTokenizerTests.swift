import XCTest
@testable import KDL

final class KDLTokenizerTests: XCTestCase {
    func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizer("node 1 2 3")
        XCTAssertEqual(try tokenizer.peekToken(), .IDENT("node"))
        XCTAssertEqual(try tokenizer.peekTokenAfterNext(), .WS)
    }

    func testIdentifier() throws {
        print("test foo")
        XCTAssertEqual(try KDLTokenizer("foo").nextToken(), .IDENT("foo"))
        print("test foo bar")
        XCTAssertEqual(try KDLTokenizer("foo-bar123").nextToken(), .IDENT("foo-bar123"))
        print("test dash")
        XCTAssertEqual(try KDLTokenizer("-").nextToken(), .IDENT("-"))
        print("test double dash")
        XCTAssertEqual(try KDLTokenizer("--").nextToken(), .IDENT("--"))
    }
}
