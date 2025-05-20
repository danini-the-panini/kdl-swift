import Testing
import Foundation
@testable import KDL

let TEST_CASES = "./Tests/kdl-org/tests/test_cases/"
let TEST_CASES_V1 = "./TEsts/v1/tests/test_cases/"

@Suite("Spec tests")
final class SpecTests {
    let fm : FileManager

    init() {
        fm = FileManager.default
    }

    @Test func testSpecsV1() throws {
        try _runSpecs(version: 1)
    }

    @Test func testSpecsV2() throws {
        try _runSpecs(version: 2)
    }

    func _runSpecs(version: UInt) throws {
        let testCases = version == 1 ? TEST_CASES_V1 : TEST_CASES
        let INPUTS = "\(testCases)/input"
        let EXPECTED = "\(testCases)/expected_kdl"
        let files = try fm.contentsOfDirectory(atPath: INPUTS)
        for file in files {
            let input = _readFile("\(INPUTS)/\(file)")
            if fm.fileExists(atPath: "\(EXPECTED)/\(file)") {
                let expected = _readFile("\(EXPECTED)/\(file)")
                #expect(throws: Never.self, "\(file) failed to parse") {
                    let actual = String(describing: try KDL.parseDocument(input, version: version))
                    #expect(actual == expected, "\(file) did not match expected")
                }
            } else {
                #expect(throws: (any Error).self, "\(file) did not fail to parse") {
                    try KDL.parseDocument(input, version: version)
                }
            }
        }
    }

    func _readFile(_ path: String) -> String {
        return String(data: fm.contents(atPath: path)!, encoding: .utf8)!
    }
}
