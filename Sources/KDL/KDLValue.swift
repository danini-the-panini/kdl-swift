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
        case .string(let s, _, let version): return .string(s, type, version)
        case .int(let i, _, let version): return .int(i, type, version)
        case .bigint(let i, _, let version): return .bigint(i, type, version)
        case .float(let f, _, let version): return .float(f, type, version)
        case .decimal(let d, _, let version): return .decimal(d, type, version)
        case .bool(let b, _, let version): return .bool(b, type, version)
        case .null(_, let version): return .null(type, version)
        }
    }

    public var description: String {
        switch self {
        case
            .string(_, let t, let version),
            .int(_, let t, let version),
            .bigint(_, let t, let version),
            .float(_, let t, let version),
            .decimal(_, let t, let version),
            .bool(_, let t, let version),
            .null(let t, let version):
                switch t {
                    case .none: return valueAsString()
                    case .some(let t):
                        switch version {
                            case 1: return "(\(StringDumperV1(t).dump()))\(valueAsString())"
                            default: return "(\(StringDumper(t).dump()))\(valueAsString())"
                        }
                }
        }
    }

    func valueAsString() -> String {
        switch self {
        case .string(let s, _, let version):
            switch version {
            case 1: return StringDumperV1(s).dumpRaw()
            default: return StringDumper(s).dump()
            }
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
        case .null(_, let version):
            switch version {
            case 1: return "null"
            default: return "#null"
            }
        }
    }
}
