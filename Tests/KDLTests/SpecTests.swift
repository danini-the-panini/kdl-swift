import Testing
import Foundation
@testable import KDL

let TEST_CASES = "./Tests/kdl-org/tests/test_cases/"
let INPUTS = "\(TEST_CASES)/input"
let EXPECTED = "\(TEST_CASES)/expected_kdl"

@Suite("Spec tests")
final class SpecTests {
    let fm : FileManager

    init() {
        fm = FileManager.default
    }

    @Test func testSpecs() throws {
        let files = try fm.contentsOfDirectory(atPath: INPUTS)
        for file in files {
            let input = _readFile("\(INPUTS)/\(file)")
            if fm.fileExists(atPath: "\(EXPECTED)/\(file)") {
                let expected = _readFile("\(EXPECTED)/\(file)")
                #expect(String(describing: try KDL.parseDocument(input)) == expected, "\(file) did not match expected")
            } else {
                #expect(throws: (any Error).self, "\(file) did not fail to parse") {
                    try KDL.parseDocument(input)
                }
            }
        }
    }

    func _readFile(_ path: String) -> String {
        return String(data: fm.contents(atPath: path)!, encoding: .utf8)!
    }
}
