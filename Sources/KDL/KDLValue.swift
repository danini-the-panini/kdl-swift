enum KDLValue: Equatable {
    case string(String, String? = nil)
    case int(Int, String? = nil)
    case float(Float, String? = nil)
    case bool(Bool, String? = nil)
    case null(String? = nil)

    public func asType(_ type: String) -> KDLValue {
        switch self {
        case .string(let s, _): return .string(s, type)
        case .int(let i, _): return .int(i, type)
        case .float(let f, _): return .float(f, type)
        case .bool(let b, _): return .bool(b, type)
        case .null(_): return .null(type)
        }
    }
}