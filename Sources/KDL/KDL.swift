public struct KDL {
    public enum KDLError : Error {
        case unknownVersion(UInt)
    }

    public static func parseDocument(_ string: String, version: UInt? = nil, outputVersion: UInt? = nil) throws -> KDLDocument {
        let outputVersion = outputVersion ?? version
        switch version {
            case 1: return try KDLParserV1(outputVersion: outputVersion).parse(string)
            case 2: return try KDLParser(outputVersion: outputVersion).parse(string)
            case nil: return try _autoParse(string, outputVersion: outputVersion)
            default: throw KDLError.unknownVersion(version!)
        }
    }

    static func _autoParse(_ string: String, outputVersion: UInt? = nil) throws -> KDLDocument {
        do {
            return try KDLParser(outputVersion: outputVersion).parse(string)
        } catch {
            return try KDLParserV1(outputVersion: outputVersion).parse(string)
        }
    }
}
