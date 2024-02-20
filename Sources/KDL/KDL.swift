public struct KDL {
    public static func parseDocument(_ string: String) throws -> KDLDocument {
        return try KDLParser().parse(string)
    }
}