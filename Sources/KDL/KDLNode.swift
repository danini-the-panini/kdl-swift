public struct KDLNode {
  var name: String
  var arguments: [KDLValue] = []
  var properties: [String:KDLValue] = [:]
  var children: [KDLNode] = []

  init(name: String, arguments: [KDLValue] = [], properties: [String:KDLValue] = [:], children: [KDLNode] = []) {
    self.name = name
    self.arguments = arguments
    self.properties = properties
    self.children = children
  }
}