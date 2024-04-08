import Foundation
import BigDecimal
import BigInt

public enum KDLValue: Equatable, CustomStringConvertible {
    case string(String, String? = nil)
    case int(Int, String? = nil)
    case bigint(BInt, String? = nil)
    case float(Float, String? = nil)
    case decimal(BigDecimal, String? = nil)
    case bool(Bool, String? = nil)
    case null(String? = nil)

    public func asType(_ type: String) -> KDLValue {
        switch self {
        case .string(let s, _): return .string(s, type)
        case .int(let i, _): return .int(i, type)
        case .bigint(let i, _): return .bigint(i, type)
        case .float(let f, _): return .float(f, type)
        case .decimal(let d, _): return .decimal(d, type)
        case .bool(let b, _): return .bool(b, type)
        case .null(_): return .null(type)
        }
    }

    public var description: String {
        switch self {
        case .string(_, let t), .int(_, let t), .bigint(_, let t), .float(_, let t), .decimal(_, let t), .bool(_, let t), .null(let t):
            switch t {
                case .none: return valueAsString()
                case .some(let t): return "(\(StringDumper(t).dump()))\(valueAsString())"
            }
        }
    }

    func valueAsString() -> String {
        switch self {
        case .string(let s, _): return StringDumper(s).dump()
        case .int(let i, _): return "\(i)"
        case .bigint(let i, _): return "\(i)"
        case .float(let f, _):
            if f.isNaN { return "#nan" }
            if f == Float.infinity { return "#inf" }
            if f == -Float.infinity { return "#-inf" }
            return "\(f)"
        case .decimal(let d, _): return "\(d)"
        case .bool(let b, _): return b ? "#true" : "#false"
        case .null(_): return "#null"
        }
    }
}
