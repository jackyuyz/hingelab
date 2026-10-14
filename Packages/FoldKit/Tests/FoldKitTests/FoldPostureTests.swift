import Testing
@testable import FoldKit

@Suite("FoldPosture Tests")
struct FoldPostureTests {
    
    @Test("hasHinge returns false only for noHinge")
    func testHasHinge() {
        #expect(FoldPosture.noHinge.hasHinge == false)
        #expect(FoldPosture.closed.hasHinge == true)
        #expect(FoldPosture.partiallyOpen.hasHinge == true)
        #expect(FoldPosture.fullyOpen.hasHinge == true)
        #expect(FoldPosture.unknown.hasHinge == true)
    }
    
    @Test("displayName returns human-readable strings")
    func testDisplayName() {
        #expect(FoldPosture.noHinge.displayName == "No Hinge")
        #expect(FoldPosture.closed.displayName == "Closed")
        #expect(FoldPosture.partiallyOpen.displayName == "Partially Open")
        #expect(FoldPosture.fullyOpen.displayName == "Fully Open")
        #expect(FoldPosture.unknown.displayName == "Unknown")
    }
    
    @Test("FoldPosture is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for posture in FoldPosture.allCases {
            let data = try encoder.encode(posture)
            let decoded = try decoder.decode(FoldPosture.self, from: data)
            #expect(decoded == posture)
        }
    }
    
    @Test("FoldPosture raw values are stable strings")
    func testRawValues() {
        #expect(FoldPosture.noHinge.rawValue == "noHinge")
        #expect(FoldPosture.closed.rawValue == "closed")
        #expect(FoldPosture.partiallyOpen.rawValue == "partiallyOpen")
        #expect(FoldPosture.fullyOpen.rawValue == "fullyOpen")
        #expect(FoldPosture.unknown.rawValue == "unknown")
    }
}
