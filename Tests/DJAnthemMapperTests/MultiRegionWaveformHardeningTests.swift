import XCTest
@testable import DJAnthemMapper

// PHASE_4C2D_ZOOM_CLIPPING_OVERLAP_HARDENING
final class MultiRegionWaveformHardeningTests: XCTestCase {
    private let eps = 0.000_001
    private func item(_ s: Double, _ e: Double) -> AnthemRegionItem { AnthemRegionItem(id: UUID(), region: AnthemRegion(start: s, end: e)) }
    private func layout(_ regions: [AnthemRegionItem], active: UUID, start: Double, duration: Double, width: Double = 1000) -> [MultiRegionWaveformGeometry.RegionGeometry] {
        MultiRegionWaveformGeometry.layout(regions: regions, activeRegionID: active, viewport: WaveformViewport(start: start, duration: duration, width: width))
    }
    func testAllCertifiedZoomDurationsKeepCentredRegionGeometryStable() {
        for d in [209.215,30,15,10,5,1,0.5] {
            let start = 100.0
            let r = item(start + d * 0.25, start + d * 0.75)
            let g = layout([r], active:r.id, start:start, duration:d)[0]
            XCTAssertEqual(g.startX!,250,accuracy:eps); XCTAssertEqual(g.endX!,750,accuracy:eps); XCTAssertEqual(g.shadeWidth!,500,accuracy:eps)
        }
    }
    func testLeftClippingAtHalfSecondZoom() { let r=item(9.9,10.25); let g=layout([r],active:r.id,start:10,duration:0.5)[0]; XCTAssertNil(g.startX); XCTAssertEqual(g.endX!,500,accuracy:eps); XCTAssertEqual(g.shadeX!,0,accuracy:eps); XCTAssertEqual(g.shadeWidth!,500,accuracy:eps) }
    func testRightClippingAtHalfSecondZoom() { let r=item(10.25,10.6); let g=layout([r],active:r.id,start:10,duration:0.5)[0]; XCTAssertEqual(g.startX!,500,accuracy:eps); XCTAssertNil(g.endX); XCTAssertEqual(g.shadeX!,500,accuracy:eps); XCTAssertEqual(g.shadeWidth!,500,accuracy:eps) }
    func testRegionSpanningHalfSecondViewportFillsViewport() { let r=item(9,12); let g=layout([r],active:r.id,start:10,duration:0.5)[0]; XCTAssertNil(g.startX); XCTAssertNil(g.endX); XCTAssertEqual(g.shadeX!,0,accuracy:eps); XCTAssertEqual(g.shadeWidth!,1000,accuracy:eps) }
    func testOverlapRemainsIndependentWhenBothClipped() { let a=item(9.8,10.35), b=item(10.2,10.8); let g=layout([a,b],active:a.id,start:10,duration:0.5); XCTAssertEqual(g.count,2); XCTAssertEqual(g[0].id,a.id); XCTAssertEqual(g[1].id,b.id); XCTAssertEqual(g[0].shadeX!,0,accuracy:eps); XCTAssertEqual(g[0].shadeWidth!,700,accuracy:eps); XCTAssertEqual(g[1].shadeX!,400,accuracy:eps); XCTAssertEqual(g[1].shadeWidth!,600,accuracy:eps) }
    func testOffscreenRegionsRemainEmptyAtEveryZoom() { for d in [30.0,15,10,5,1,0.5] { let a=item(0,1), b=item(200,201); let g=layout([a,b],active:a.id,start:50,duration:d); for x in g { XCTAssertNil(x.shadeX); XCTAssertNil(x.shadeWidth) } } }
    func testSwitchingActiveIdentityDoesNotChangeOverlapGeometry() { let a=item(10,20), b=item(15,25), c=item(18,22); let rs=[a,b,c]; let x=layout(rs,active:a.id,start:12,duration:12), y=layout(rs,active:c.id,start:12,duration:12); for i in rs.indices { XCTAssertEqual(x[i].shadeX,y[i].shadeX); XCTAssertEqual(x[i].shadeWidth,y[i].shadeWidth); XCTAssertEqual(x[i].startX,y[i].startX); XCTAssertEqual(x[i].endX,y[i].endX) } }
    func testManyOverlappingRegionsPreserveSourceOrderAndGeometry() { let rs=(0..<8).map { item(10+Double($0),30-Double($0)) }; let g=layout(rs,active:rs[3].id,start:10,duration:20); XCTAssertEqual(g.map(\.id),rs.map(\.id)); XCTAssertEqual(g.filter(\.isActive).count,1); XCTAssertEqual(g.first(where:{$0.isActive})?.id,rs[3].id); XCTAssertTrue(g.allSatisfy{$0.hasVisibleShading}) }
}
