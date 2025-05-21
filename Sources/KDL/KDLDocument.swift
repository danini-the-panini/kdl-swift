public struct KDLDocument: Equatable, CustomStringConvertible {
    var nodes: [KDLNode] = []
    var version: UInt

    init(_ nodes: [KDLNode] = [], version: UInt = 2) {
        self.nodes = nodes
        self.version = version
    }

    public subscript(index: Int) -> KDLNode {
        get {
            return nodes[index]
        }
        set(value) {
            nodes[index] = value
        }
    }

    public subscript(key: String) -> KDLNode? {
        return nodes.first { $0.name == key }
    }

    public func arg(_ index: Int) -> KDLValue? {
        return self[index].arg
    }

    public func arg(_ key: String) -> KDLValue? {
        return self[key]?.arg
    }

    public func args(_ index: Int) -> [KDLValue] {
        return self[index].arguments
    }

    public func args(_ key: String) -> [KDLValue]? {
        return self[key]?.arguments
    }

    public func dashVals(_ index: Int) -> [KDLValue?] {
        return self[index].dashVals
    }

    public func dashVals(_ key: String) -> [KDLValue?]? {
        return self[key]?.dashVals
    }

    public var description: String {
        return nodes.map({ $0.fmt() }).joined(separator: "\n") + "\n"
    }

    public static func == (lhs: KDLDocument, rhs: KDLDocument) -> Bool {
        return lhs.nodes == rhs.nodes
    }
}
