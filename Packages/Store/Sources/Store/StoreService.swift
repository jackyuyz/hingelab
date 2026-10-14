import Foundation
import Instruments

public enum ProductIdentifier: String, CaseIterable, Sendable {
    case full = "com.jackyu.hingelab.full"
    case reedPack = "com.jackyu.hingelab.pack.reeds"
    case guitarPack = "com.jackyu.hingelab.pack.guitar"
    case filterPack = "com.jackyu.hingelab.pack.filter"
    case thereminPack = "com.jackyu.hingelab.pack.theremin"

    public var isFullUnlock: Bool { self == .full }
}

public struct StoreProduct: Equatable, Sendable, Identifiable {
    public var id: ProductIdentifier
    public var displayName: String
    /// Localized price string from StoreKit. Never hardcode in UI.
    public var displayPrice: String

    public init(id: ProductIdentifier, displayName: String, displayPrice: String) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
    }
}

public struct Entitlements: Equatable, Sendable, Codable {
    public var hasFull: Bool
    public var ownedPacks: Set<String>
    public var cachedAt: Date?

    public init(hasFull: Bool = false, ownedPacks: Set<String> = [], cachedAt: Date? = nil) {
        self.hasFull = hasFull
        self.ownedPacks = ownedPacks
        self.cachedAt = cachedAt
    }

    public func isUnlocked(_ instrument: InstrumentID) -> Bool {
        instrument.isFree || hasFull
    }

    public var maxLoopTracks: Int {
        hasFull ? 8 : 1
    }

    public var midiEnabled: Bool { hasFull }
    public var audioExportEnabled: Bool { hasFull }
}

public enum PurchaseResult: Equatable, Sendable {
    case success
    case pending
    case userCancelled
    case unverified
    case failed(String)
}

public enum PurchaseState: Equatable, Sendable {
    case idle
    case loading
    case purchasing
    case pending
    case purchased
    case offline
    case failed(String)
}

public protocol StoreServicing: AnyObject, Sendable {
    var entitlements: Entitlements { get }
    var purchaseState: PurchaseState { get }
    var products: [StoreProduct] { get }
    func loadProducts() async
    func purchase(_ id: ProductIdentifier) async -> PurchaseResult
    func restore() async
    func applyRefund(_ id: ProductIdentifier)
    func applyUnverified(_ id: ProductIdentifier)
}

public final class MockStore: StoreServicing, @unchecked Sendable {
    public private(set) var entitlements: Entitlements
    public private(set) var purchaseState: PurchaseState = .idle
    public private(set) var products: [StoreProduct]
    public var nextPurchaseResult: PurchaseResult = .success
    public var isOffline = false
    public var restoreGrantsFull = true

    public init(entitlements: Entitlements = Entitlements()) {
        self.entitlements = entitlements
        self.products = [
            StoreProduct(id: .full, displayName: "HingeLab Full", displayPrice: "$3.99"),
            StoreProduct(id: .reedPack, displayName: "Reed Pack", displayPrice: "$0.99"),
            StoreProduct(id: .guitarPack, displayName: "Guitar Pack", displayPrice: "$0.99"),
            StoreProduct(id: .filterPack, displayName: "Filter Pack", displayPrice: "$0.99"),
            StoreProduct(id: .thereminPack, displayName: "Theremin Pack", displayPrice: "$0.99"),
        ]
    }

    public func loadProducts() async {
        purchaseState = isOffline ? .offline : .idle
    }

    public func purchase(_ id: ProductIdentifier) async -> PurchaseResult {
        if isOffline {
            purchaseState = .offline
            return .failed("offline")
        }
        purchaseState = .purchasing
        let result = nextPurchaseResult
        switch result {
        case .success:
            grant(id)
            purchaseState = .purchased
        case .pending:
            purchaseState = .pending
        case .unverified:
            purchaseState = .idle
        case .userCancelled:
            purchaseState = .idle
        case .failed(let message):
            purchaseState = .failed(message)
        }
        return result
    }

    public func restore() async {
        if restoreGrantsFull {
            grant(.full)
            purchaseState = .purchased
        }
    }

    public func applyRefund(_ id: ProductIdentifier) {
        if id == .full {
            entitlements.hasFull = false
        } else {
            entitlements.ownedPacks.remove(id.rawValue)
        }
        if !entitlements.hasFull {
            purchaseState = .idle
        }
    }

    public func applyUnverified(_ id: ProductIdentifier) {
        _ = id
        // .unverified grants nothing
    }

    private func grant(_ id: ProductIdentifier) {
        if id == .full {
            entitlements.hasFull = true
        } else {
            entitlements.ownedPacks.insert(id.rawValue)
        }
        entitlements.cachedAt = Date()
    }
}

public struct EntitlementCache: Sendable {
    public static let key = "hingelab.entitlements"

    public static func save(_ entitlements: Entitlements, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(entitlements) {
            defaults.set(data, forKey: key)
        }
    }

    public static func load(defaults: UserDefaults = .standard) -> Entitlements? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Entitlements.self, from: data)
    }
}
