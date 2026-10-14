import Testing
import Instruments
@testable import Store

@Suite("Entitlements")
struct EntitlementTests {
    @Test("Free is accordion + 1 loop, Full unlocks the rest")
    func gating() {
        let free = Entitlements()
        #expect(free.isUnlocked(.accordion))
        #expect(!free.isUnlocked(.pitchBendGuitar))
        #expect(!free.isUnlocked(.filterSweep))
        #expect(!free.isUnlocked(.theremin))
        #expect(free.maxLoopTracks == 1)
        #expect(!free.midiEnabled)

        let full = Entitlements(hasFull: true)
        for id in InstrumentID.allCases {
            #expect(full.isUnlocked(id))
        }
        #expect(full.maxLoopTracks == 8)
        #expect(full.midiEnabled)
        #expect(full.audioExportEnabled)
    }

    @Test("Full product lists the confirmed $4.99 price")
    func fullPrice() {
        let store = MockStore()
        let full = store.products.first { $0.id == .full }
        #expect(full?.displayPrice == "$4.99")
        #expect(ProductIdentifier.full.rawValue == "com.jackyu.hingelab.full")
    }
}

@Suite("Mock StoreKit flow")
struct MockStoreTests {
    @Test("Purchase success grants Full immediately")
    func success() async {
        let store = MockStore()
        store.nextPurchaseResult = .success
        let result = await store.purchase(.full)
        #expect(result == .success)
        #expect(store.entitlements.hasFull)
        #expect(store.purchaseState == .purchased)
    }

    @Test("Pending Ask to Buy does not grant")
    func pending() async {
        let store = MockStore()
        store.nextPurchaseResult = .pending
        let result = await store.purchase(.full)
        #expect(result == .pending)
        #expect(!store.entitlements.hasFull)
        #expect(store.purchaseState == .pending)
    }

    @Test("Unverified grants nothing")
    func unverified() async {
        let store = MockStore()
        store.nextPurchaseResult = .unverified
        _ = await store.purchase(.full)
        #expect(!store.entitlements.hasFull)
        store.applyUnverified(.full)
        #expect(!store.entitlements.hasFull)
    }

    @Test("Refund removes Full; loops stay representable")
    func refund() async {
        let store = MockStore()
        store.nextPurchaseResult = .success
        _ = await store.purchase(.full)
        store.applyRefund(.full)
        #expect(!store.entitlements.hasFull)
        #expect(store.entitlements.maxLoopTracks == 1)
    }

    @Test("Instrument packs are tracked separately")
    func packs() async {
        let store = MockStore()
        store.nextPurchaseResult = .success
        _ = await store.purchase(.reedPack)
        #expect(store.entitlements.ownedPacks.contains(ProductIdentifier.reedPack.rawValue))
        #expect(!store.entitlements.hasFull)
    }

    @Test("Cancel is silent")
    func cancel() async {
        let store = MockStore()
        store.nextPurchaseResult = .userCancelled
        let result = await store.purchase(.full)
        #expect(result == .userCancelled)
        #expect(store.purchaseState == .idle)
    }

    @Test("Offline load")
    func offline() async {
        let store = MockStore()
        store.isOffline = true
        await store.loadProducts()
        #expect(store.purchaseState == .offline)
    }

    @Test("Restore grants Full")
    func restore() async {
        let store = MockStore()
        await store.restore()
        #expect(store.entitlements.hasFull)
    }
}
