import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case en
    case zhHans = "zh-Hans"

    public static let `default`: AppLanguage = .en
    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }

    public var localeIdentifier: String { rawValue }

    public init?(languageCode: String) {
        let normalized = languageCode.replacingOccurrences(of: "_", with: "-")
        if let exact = AppLanguage(rawValue: normalized) {
            self = exact
            return
        }
        switch normalized.lowercased() {
        case "en", "en-us", "en-gb": self = .en
        case "zh-hans", "zh-cn", "zh-sg", "zh": self = .zhHans
        default: return nil
        }
    }
}
