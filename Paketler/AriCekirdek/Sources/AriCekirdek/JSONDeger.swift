import Foundation

/// Ham JSON değeri. Web'in yazdığı her alanı (bilinmeyenler dahil) kayıpsız taşır.
public enum JSONDeger: Codable, Equatable, Sendable {
    case yok
    case bool(Bool)
    case tam(Int64)
    case ondalik(Double)
    case metin(String)
    case dizi([JSONDeger])
    case nesne([String: JSONDeger])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .yok; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int64.self) { self = .tam(i); return }
        if let d = try? c.decode(Double.self) { self = .ondalik(d); return }
        if let s = try? c.decode(String.self) { self = .metin(s); return }
        if let a = try? c.decode([JSONDeger].self) { self = .dizi(a); return }
        if let o = try? c.decode([String: JSONDeger].self) { self = .nesne(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Tanınmayan JSON değeri")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .yok: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .tam(let i): try c.encode(i)
        case .ondalik(let d): try c.encode(d)
        case .metin(let s): try c.encode(s)
        case .dizi(let a): try c.encode(a)
        case .nesne(let o): try c.encode(o)
        }
    }

    public subscript(anahtar: String) -> JSONDeger? {
        if case .nesne(let o) = self { return o[anahtar] }
        return nil
    }

    /// JS `Number(x)` benzeri: sayılar ve sayısal metinler; boş/geçersiz metin → nil.
    public var sayi: Double? {
        switch self {
        case .tam(let i): return Double(i)
        case .ondalik(let d): return d
        case .metin(let s):
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, let d = Double(t), d.isFinite else { return nil }
            return d
        default: return nil
        }
    }

    public var metinDegeri: String? {
        switch self {
        case .metin(let s): return s
        case .tam(let i): return String(i)
        case .ondalik(let d): return sayiMetni(d)
        default: return nil
        }
    }

    public var boolDegeri: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    public var diziDegeri: [JSONDeger]? {
        if case .dizi(let a) = self { return a }
        return nil
    }

    public var nesneDegeri: [String: JSONDeger]? {
        if case .nesne(let o) = self { return o }
        return nil
    }

    /// Sayıyı web'e yakın biçimde saklar: tam sayıysa `.tam`, değilse `.ondalik`.
    public static func sayidan(_ d: Double) -> JSONDeger {
        if d.isFinite, d == d.rounded(), abs(d) < 9e15 { return .tam(Int64(d)) }
        return .ondalik(d)
    }
}

/// JS sayı yazımı: tam değerli ondalık "5", diğerleri en kısa gösterim.
func sayiMetni(_ d: Double) -> String {
    if d.isFinite, d == d.rounded(), abs(d) < 9e15 { return String(Int64(d)) }
    return "\(d)"
}

/// JS `JSON.stringify` metin kaçışı.
func jsonMetni(_ s: String) -> String {
    var o = "\""
    for u in s.unicodeScalars {
        switch u {
        case "\"": o += "\\\""
        case "\\": o += "\\\\"
        case "\n": o += "\\n"
        case "\r": o += "\\r"
        case "\t": o += "\\t"
        case "\u{08}": o += "\\b"
        case "\u{0C}": o += "\\f"
        default:
            if u.value < 0x20 { o += String(format: "\\u%04x", u.value) } else { o.unicodeScalars.append(u) }
        }
    }
    return o + "\""
}

/// Web `bbStable`: anahtarları sıralı, deterministik metin (içerik karşılaştırması için).
public func kararliMetin(_ d: JSONDeger) -> String {
    switch d {
    case .yok: return "null"
    case .bool(let b): return b ? "true" : "false"
    case .tam(let i): return String(i)
    case .ondalik(let x): return sayiMetni(x)
    case .metin(let s): return jsonMetni(s)
    case .dizi(let a): return "[" + a.map(kararliMetin).joined(separator: ",") + "]"
    case .nesne(let o):
        return "{" + o.keys.sorted().map { jsonMetni($0) + ":" + kararliMetin(o[$0]!) }.joined(separator: ",") + "}"
    }
}
