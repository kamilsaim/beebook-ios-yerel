import Foundation

private let base36 = Array("0123456789abcdefghijklmnopqrstuvwxyz")

/// Web `genId()` ile aynı biçim: `Date.now().toString(36)` + 5 rastgele base36 karakter.
public func yeniKimlik(simdi: Date = Date()) -> String {
    let ms = Int64((simdi.timeIntervalSince1970 * 1000).rounded())
    var g = SystemRandomNumberGenerator()
    let ek = String((0..<5).map { _ in base36[Int.random(in: 0..<36, using: &g)] })
    return String(ms, radix: 36) + ek
}
