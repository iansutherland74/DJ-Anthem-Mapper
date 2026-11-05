import XCTest
@testable import DJAnthemMapper

final class AnthemMapSessionTests: XCTestCase {
    func testNilMapURLCreatesUnassociatedSession() throws {
        let session = AnthemMapSession(mapURL: nil, baseline: try snapshot(regions: [item(start: 10, end: 20)]))

        XCTAssertFalse(session.hasAssociatedMap)
        XCTAssertNil(session.mapURL)
    }

    func testMapURLCreatesAssociatedSession() throws {
        let session = AnthemMapSession(mapURL: mapURL(), baseline: try snapshot(regions: [item(start: 10, end: 20)]))

        XCTAssertTrue(session.hasAssociatedMap)
    }

    func testSuppliedURLIsPreservedExactly() throws {
        let url = URL(fileURLWithPath: "/Maps/../Maps/Set.anthemmap")
        let session = AnthemMapSession(mapURL: url, baseline: try snapshot(regions: [item(start: 10, end: 20)]))

        XCTAssertEqual(session.mapURL, url)
    }

    func testBaselineSnapshotIsPreservedExactly() throws {
        let baseline = try snapshot(regions: [item(start: 10), item(end: 20)])
        let session = AnthemMapSession(mapURL: nil, baseline: baseline)

        XCTAssertEqual(session.baseline, baseline)
    }

    func testIdenticalCurrentContentIsClean() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let session = AnthemMapSession(mapURL: nil, baseline: baseline)

        XCTAssertEqual(session.dirtyState(current: baseline), .clean)
    }

    func testStartChangeIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: id, start: 11, end: 20)])

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testEndChangeIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: id, start: 10, end: 21)])

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testAddedRegionIsDirty() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first])
        let current = try snapshot(regions: [first, second])

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testDeletedRegionIsDirty() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second])
        let current = try snapshot(regions: [first])

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testUUIDChangeIsDirty() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testOrderChangeIsDirty() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [second, first], activeRegionID: first.id)

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testIncompleteRegionChangeIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10)])
        let current = try snapshot(regions: [item(id: id, start: 11)])

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .dirty)
    }

    func testActiveRegionOnlyChangeIsClean() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [first, second], activeRegionID: second.id)

        XCTAssertEqual(AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current), .clean)
    }

    func testMultipleActiveSelectionChangesRemainClean() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let third = item(start: 50, end: 60)
        let baseline = try snapshot(regions: [first, second, third], activeRegionID: first.id)
        let session = AnthemMapSession(mapURL: nil, baseline: baseline)
        let selectingSecond = try snapshot(regions: [first, second, third], activeRegionID: second.id)
        let selectingThird = try snapshot(regions: [first, second, third], activeRegionID: third.id)

        XCTAssertEqual(session.dirtyState(current: selectingSecond), .clean)
        XCTAssertEqual(session.dirtyState(current: selectingThird), .clean)
    }

    func testExactContentRevertIsClean() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let changed = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])
        let session = AnthemMapSession(mapURL: nil, baseline: baseline)

        XCTAssertEqual(session.dirtyState(current: changed), .dirty)
        XCTAssertEqual(session.dirtyState(current: baseline), .clean)
    }

    func testChangingOnlyMapURLDoesNotAlterDirtyState() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])
        let newSession = AnthemMapSession(mapURL: nil, baseline: baseline)
        let associatedSession = AnthemMapSession(mapURL: mapURL(), baseline: baseline)

        XCTAssertEqual(newSession.dirtyState(current: current), associatedSession.dirtyState(current: current))
    }

    func testEvaluationDoesNotMutateBaseline() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let before = baseline
        let current = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])

        _ = AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current)

        XCTAssertEqual(baseline, before)
    }

    func testEvaluationDoesNotMutateCurrentSnapshot() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])
        let before = current

        _ = AnthemMapSession(mapURL: nil, baseline: baseline).dirtyState(current: current)

        XCTAssertEqual(current, before)
    }

    func testEightRegionSnapshotsEvaluateNormally() throws {
        var regions: [AnthemRegionItem] = []
        for index in 0..<8 {
            let start = TimeInterval(index * 10)
            regions.append(item(start: start, end: start + 5))
        }
        let baseline = try snapshot(regions: regions)
        let current = try snapshot(regions: regions, activeRegionID: regions[7].id)

        XCTAssertEqual(AnthemMapSession(mapURL: mapURL(), baseline: baseline).dirtyState(current: current), .clean)
    }

    func testSessionMatchesDirectDirtyStateEvaluation() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let cleanCurrent = try snapshot(regions: [baseline.regions[0]], activeRegionID: baseline.regions[0].id)
        let dirtyCurrent = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])
        let direct = AnthemRegionDirtyState(baseline: baseline)
        let session = AnthemMapSession(mapURL: mapURL(), baseline: baseline)

        XCTAssertEqual(session.dirtyState(current: cleanCurrent), direct.evaluate(current: cleanCurrent))
        XCTAssertEqual(session.dirtyState(current: dirtyCurrent), direct.evaluate(current: dirtyCurrent))
    }

    func testSessionUsesOnlySuppliedURLAndSnapshots() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let session = AnthemMapSession(mapURL: URL(string: "custom://session"), baseline: baseline)

        XCTAssertTrue(session.hasAssociatedMap)
        XCTAssertEqual(session.dirtyState(current: baseline), .clean)
    }

    private func mapURL() -> URL {
        URL(fileURLWithPath: "/Maps/Set.anthemmap")
    }

    private func snapshot(
        regions: [AnthemRegionItem],
        activeRegionID: UUID? = nil
    ) throws -> AnthemRegionSnapshot {
        try AnthemRegionSnapshot(regions: regions, activeRegionID: activeRegionID ?? regions[0].id)
    }

    private func item(
        id: UUID = UUID(),
        start: TimeInterval? = nil,
        end: TimeInterval? = nil
    ) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }
}
