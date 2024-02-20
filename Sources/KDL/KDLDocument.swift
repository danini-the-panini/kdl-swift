public struct KDLDocument: Equatable, CustomStringConvertible {
    var nodes: [KDLNode] = []

    init(_ nodes: [KDLNode] = []) {
        self.nodes = nodes
    }

    public var description: String {
        return nodes.map({ $0.fmt() }).joined(separator: "\n") + "\n"
    }

    public static func == (lhs: KDLDocument, rhs: KDLDocument) -> Bool {
        return lhs.nodes == rhs.nodes
    }
}