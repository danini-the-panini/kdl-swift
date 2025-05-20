import Foundation
import BigDecimal
import BigInt

public enum KDLValue: Equatable, CustomStringConvertible {
    case string(String, String? = nil, UInt = 2)
    case int(Int, String? = nil, UInt = 2)
    case bigint(BInt, String? = nil, UInt = 2)
    case float(Float, String? = nil, UInt = 2)
    case decimal(BigDecimal, String? = nil, UInt = 2)
    case bool(Bool, String? = nil, UInt = 2)
    case null(String? = nil, UInt = 2)

    public func asType(_ type: String) -> KDLValue {
        switch self {
        case .string(let s, _, _): return .string(s, type)
        case .int(let i, _, _): return .int(i, type)
        case .bigint(let i, _, _): return .bigint(i, type)
        case .float(let f, _, _): return .float(f, type)
        case .decimal(let d, _, _): return .decimal(d, type)
        case .bool(let b, _, _): return .bool(b, type)
        case .null(_, _): return .null(type)
        }
    }

    public var description: String {
        switch self {
        case .string(_, let t, _), .int(_, let t, _), .bigint(_, let t, _), .float(_, let t, _), .decimal(_, let t, _), .bool(_, let t, _), .null(let t, _):
            switch t {
                case .none: return valueAsString()
                case .some(let t): return "(\(StringDumper(t).dump()))\(valueAsString())"
            }
        }
    }

    func valueAsString() -> String {
        switch self {
        case .string(let s, _, _): return StringDumper(s).dump()
        case .int(let i, _, _): return "\(i)"
        case .bigint(let i, _, _): return "\(i)"
        case .float(let f, _, _):
            if f.isNaN { return "#nan" }
            if f == Float.infinity { return "#inf" }
            if f == -Float.infinity { return "#-inf" }
            return "\(f)"
        case .decimal(let d, _, _): return "\(d)"
        case .bool(let b, _, let version):
            switch version {
                case 1: return b ? "true" : "false"
                default: return b ? "#true" : "#false"
            }
        case .null(_, _): return "#null"
        }
    }
}
