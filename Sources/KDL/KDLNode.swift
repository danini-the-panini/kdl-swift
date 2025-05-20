func _idToString(_ s: String) -> String {
    return StringDumper(s).dump()
}

public struct KDLNode: Equatable, CustomStringConvertible {
    var name: String
    var arguments: [KDLValue] = []
    var properties: [String:KDLValue] = [:]
    var keys: [String] = []
    var children: [KDLNode] = []
    var type: String? = nil
    var version: UInt

    public init(_ name: String, arguments: [KDLValue] = [], properties: [String:KDLValue] = [:], children: [KDLNode] = [], type: String? = nil, version: UInt = 2) {
        self.name = name
        self.arguments = arguments
        self.properties = properties
        self.keys = Array(properties.keys)
        self.children = children
        self.type = type
        self.version = 2
    }

    public subscript(index: Int) -> KDLValue {
        get {
            return arguments[index]
        }
        set(value) {
            arguments[index] = value
        }
    }

    public subscript(key: String) -> KDLValue? {
        get {
            return properties[key]
        }
        set(value) {
            if !keys.contains(key) {
                keys.append(key)
            }
            properties[key] = value!
        }
    }

    public func child(_ index: Int) -> KDLNode {
        return children[index]
    }

    public func child(_ key: String) -> KDLNode? {
        return children.first { $0.name == key }
    }

    public var arg: KDLValue? {
        return arguments.first
    }

    public func arg(_ index: Int) -> KDLValue? {
        return child(index).arg
    }

    public  func arg(_ key: String) -> KDLValue? {
        return child(key)?.arg
    }

    public  func args(_ index: Int) -> [KDLValue] {
        return child(index).arguments
    }

    public  func args(_ key: String) -> [KDLValue]? {
        return child(key)?.arguments
    }

    public var dashVals: [KDLValue?] {
        children
            .filter { $0.name == "-" }
            .map { $0.arguments.first }
    }

    public  func dashVals(_ index: Int) -> [KDLValue?] {
        return child(index).dashVals
    }

    public  func dashVals(_ key: String) -> [KDLValue?]? {
        return child(key)?.dashVals
    }

    public var description: String {
        return fmt()
    }

    internal func fmt(depth: Int = 0) -> String {
        let indent = String(repeating: "    ", count: depth)
        let typeStr = type != nil ? "(\(_idToString(type!)))" : ""
        var s = "\(indent)\(typeStr)\(_idToString(name))";
        if !arguments.isEmpty {
            s += " \(arguments.map { String(describing: $0) }.joined(separator: " "))";
        }
        if !properties.isEmpty {
            s += " \(keys.map { "\(_idToString($0))=\(properties[$0]!)" }.joined(separator: " "))"
        }
        if !children.isEmpty {
            let childrenStr = children.map { $0.fmt(depth: depth + 1) }.joined(separator: "\n");
            s += " {\n\(childrenStr)\n\(indent)}";
        }
        return s
    }

    public static func == (lhs: KDLNode, rhs: KDLNode) -> Bool {
        return lhs.name == rhs.name &&
            lhs.arguments == rhs.arguments &&
            lhs.properties == rhs.properties &&
            lhs.children == rhs.children &&
            lhs.type == rhs.type
    }
}
