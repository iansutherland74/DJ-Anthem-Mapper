import XCTest
@testable import DJAnthemMapper

// PHASE_4C2H_MULTI_REGION_STRESS
final class MultiRegionStressTests: XCTestCase {
    private func item(_ s: Double, _ e: Double) -> AnthemRegionItem { .init(id: UUID(), region: AnthemRegion(start:s,end:e)) }
    func testHundredRegionsGeometryRemainsFiniteAndOrdered() {
        let rs=(0..<100).map { item(Double($0), Double($0)+20) }; let v=WaveformViewport(start:0,duration:120,width:1200)
        let g=MultiRegionWaveformGeometry.layout(regions:rs,activeRegionID:rs[50].id,viewport:v)
        XCTAssertEqual(g.count,100); XCTAssertEqual(g.map(\.id),rs.map(\.id)); XCTAssertEqual(g.filter(\.isActive).count,1)
        for x in g { if let p=x.shadeX { XCTAssertTrue(p.isFinite) }; if let w=x.shadeWidth { XCTAssertTrue(w.isFinite); XCTAssertGreaterThanOrEqual(w,0) } }
    }
    @MainActor func testRepeatedActiveSwitchingNeverMutatesRegionData() {
        let c=AnthemRegionController(); XCTAssertTrue(c.setStart(at:10,trackDuration:500)); XCTAssertTrue(c.setEnd(at:20,trackDuration:500))
        for n in 1..<12 { _=c.addRegion(); XCTAssertTrue(c.setStart(at:Double(n*20),trackDuration:500)); XCTAssertTrue(c.setEnd(at:Double(n*20+10),trackDuration:500)) }
        let before=c.regions; let ids=c.regions.map(\.id)
        for _ in 0..<50 { for id in ids.reversed() { XCTAssertTrue(c.selectRegion(id:id)) } }
        let after=c.regions; XCTAssertEqual(after,before)
    }
    func testHitTestingAcrossDenseOverlapIsDeterministic() {
        let active=UUID(); var gs=[MultiRegionWaveformGeometry.RegionGeometry(id:active,isActive:true,startX:10,endX:990,shadeX:10,shadeWidth:980)]; let ids=(0..<40).map { _ in UUID() }
        for id in ids { gs.append(.init(id:id,isActive:false,startX:nil,endX:nil,shadeX:100,shadeWidth:800)) }
        for _ in 0..<100 { XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:500,layouts:gs,activeRegionID:active),.selectRegion(ids.last!)) }
    }
    func testCertifiedZoomsWithManyOverlapsStayWithinViewport() {
        let rs=(0..<30).map { item(50+Double($0)*0.02,51+Double($0)*0.02) }
        for d in [30.0,15,10,5,1,0.5] { let v=WaveformViewport(start:50,duration:d,width:760); let g=MultiRegionWaveformGeometry.layout(regions:rs,activeRegionID:rs[0].id,viewport:v); for x in g { if let px=x.shadeX { XCTAssertGreaterThanOrEqual(px,0); XCTAssertLessThanOrEqual(px,760) }; if let w=x.shadeWidth { XCTAssertGreaterThanOrEqual(w,0); XCTAssertLessThanOrEqual(w,760) } } }
    }
    @MainActor func testDeleteAndReaddStressMaintainsValidActiveIdentity() {
        let c=AnthemRegionController(); XCTAssertTrue(c.setStart(at:1,trackDuration:500)); XCTAssertTrue(c.setEnd(at:2,trackDuration:500))
        for n in 0..<25 {
            _=c.addRegion(); XCTAssertTrue(c.setStart(at:Double(n+3),trackDuration:500)); XCTAssertTrue(c.setEnd(at:Double(n+4),trackDuration:500))
            let current=c.regions; if current.count>8 { XCTAssertTrue(c.deleteRegion(id:current[1].id)) }
            let active=c.activeRegionID; XCTAssertNotNil(c.collection.region(id:active))
        }
    }
}
