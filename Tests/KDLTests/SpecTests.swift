import XCTest
@testable import KDL

let TEST_CASES = "./Tests/kdl-org/tests/test_cases/"
let INPUTS = "\(TEST_CASES)/input"
let EXPECTED = "\(TEST_CASES)/expected_kdl"

final class SpecTests: XCTestCase {
    let fm = FileManager.default

    func testSpecs() throws {
        let files = try fm.contentsOfDirectory(atPath: INPUTS)
        for file in files {
            let input = _readFile("\(INPUTS)/\(file)")
            if fm.fileExists(atPath: "\(EXPECTED)/\(file)") {
                let expected = _readFile("\(EXPECTED)/\(file)")
                XCTAssertEqual(String(describing: try KDL.parseDocument(input)), expected, "\(file) did not match expected")
            } else {
                XCTAssertThrowsError(try KDL.parseDocument(input), "\(file) did not fail to parse")
            }
        }
    }

    func _readFile(_ path: String) -> String {
        return String(data: fm.contents(atPath: path)!, encoding: .utf8)!
    }
}
