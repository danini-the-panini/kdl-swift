import XCTest
@testable import KDL

final class KDLTokenizerTests: XCTestCase {
    func testPeekAndPeekAfterNext() throws {
        let tokenizer = KDLTokenizer("node 1 2 3")
        XCTAssertEqual(try tokenizer.peekToken(), .IDENT("node"))
        XCTAssertEqual(try tokenizer.peekTokenAfterNext(), .WS)
    }
}


