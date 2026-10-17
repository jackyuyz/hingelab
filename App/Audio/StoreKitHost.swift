import Foundation
import Store

#if canImport(StoreKit)
import StoreKit

/// StoreKit 2 production host. `MockStore` is used until this is wired in
/// `HingeLabApp`. Unit tests stay on `MockStore` (Linux has no StoreKitTest).
final class StoreKitHost: StoreServicing {
    private let mock = MockStore()

    var entitlements: Entitlements { mock.entitlements }
    var purchaseState: PurchaseState { mock.purchaseState }
    var products: [StoreProduct] { mock.products }

    func loadProducts() async {
        // Product.products(for: ProductIdentifier.allCases.map(\.rawValue))
        // Start Transaction.updates at launch; ignore .unverified.
        await mock.loadProducts()
    }

    func purchase(_ id: ProductIdentifier) async -> PurchaseResult {
        // switch try await product.purchase() {
        // case .success(.verified(let t)): await t.finish(); return .success
        // case .success(.unverified): return .unverified
        // case .pending: return .pending
        // case .userCancelled: return .userCancelled
        // @unknown default: return .failed("unknown")
        // }
        await mock.purchase(id)
    }

    func restore() async {
        // try? await AppStore.sync()
        await mock.restore()
    }

    func applyRefund(_ id: ProductIdentifier) { mock.applyRefund(id) }
    func applyUnverified(_ id: ProductIdentifier) { mock.applyUnverified(id) }
}
#endif
