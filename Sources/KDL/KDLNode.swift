public struct KDLNode: Equatable {
    var name: String
    var arguments: [KDLValue] = []
    var properties: [String:KDLValue] = [:]
    var children: [KDLNode] = []
    var type: String? = nil

    init(_ name: String, arguments: [KDLValue] = [], properties: [String:KDLValue] = [:], children: [KDLNode] = [], type: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.properties = properties
        self.children = children
        self.type = type
    }
    
    public static func == (lhs: KDLNode, rhs: KDLNode) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments &&
            lhs.properties == rhs.properties &&
            lhs.children == rhs.children &&
            lhs.type == rhs.type
    }
}