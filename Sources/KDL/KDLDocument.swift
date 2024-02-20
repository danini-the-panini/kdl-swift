public struct KDLDocument: Equatable {
    var nodes: [KDLNode] = []

    init(_ nodes: [KDLNode] = []) {
        self.nodes = nodes
    }

    public static func == (lhs: KDLDocument, rhs: KDLDocument) -> Bool {
        return lhs.nodes == rhs.nodes
    }
}