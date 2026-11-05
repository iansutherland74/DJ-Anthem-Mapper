import XCTest
@testable import DJAnthemMapper

final class MultiRegionWaveformHitTestingTests: XCTestCase {
    private func g(_ id: UUID, _ active: Bool, _ start: Double?, _ end: Double?, _ x: Double?, _ w: Double?) -> MultiRegionWaveformGeometry.RegionGeometry { .init(id:id,isActive:active,startX:start,endX:end,shadeX:x,shadeWidth:w) }
    func testClickInsideSingleInactiveRegionSelectsIt() { let a=UUID(),b=UUID(); XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:350,layouts:[g(a,true,100,200,100,100),g(b,false,300,400,300,100)],activeRegionID:a),.selectRegion(b)) }
    func testClickOutsideAllRegionsSeeksWaveform() { let a=UUID(),b=UUID(); XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:700,layouts:[g(a,true,100,200,100,100),g(b,false,300,400,300,100)],activeRegionID:a),.seekWaveform) }
    func testActiveMarkerStartHasPriority() { let a=UUID(),b=UUID(); XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:108,layouts:[g(a,true,100,200,100,100),g(b,false,nil,nil,90,80)],activeRegionID:a),.activeMarkerPriority) }
    func testActiveMarkerEndHasPriority() { let a=UUID(),b=UUID(); XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:190,layouts:[g(a,true,100,200,100,100),g(b,false,nil,nil,180,80)],activeRegionID:a),.activeMarkerPriority) }
    func testOverlapUsesTopmostLatestRenderedInactiveRegion() { let a=UUID(),b=UUID(),c=UUID(); let r=[g(a,true,nil,nil,0,100),g(b,false,nil,nil,200,300),g(c,false,nil,nil,300,300)]; XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:350,layouts:r,activeRegionID:a),.selectRegion(c)) }
    func testActiveRegionBodyDoesNotReselectIt() { let a=UUID(); XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:150,layouts:[g(a,true,100,200,100,100)],activeRegionID:a),.seekWaveform) }
    func testClippedInactiveRegionCanStillBeSelected() { let a=UUID(),b=UUID(); XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:25,layouts:[g(a,true,nil,nil,nil,nil),g(b,false,nil,100,0,100)],activeRegionID:a),.selectRegion(b)) }
    func testInvalidClickFallsBackToSeek() { XCTAssertEqual(MultiRegionWaveformHitTesting.decision(x:.nan,layouts:[],activeRegionID:UUID()),.seekWaveform) }
}
