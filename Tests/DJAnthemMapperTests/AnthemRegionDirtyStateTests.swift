import XCTest
@testable import DJAnthemMapper

final class AnthemRegionDirtyStateTests: XCTestCase {
    func testIdenticalSnapshotsAreClean() throws {
        let snapshot = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: snapshot).evaluate(current: snapshot), .clean)
    }

    func testActiveSelectionOnlyIsClean() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [first, second], activeRegionID: second.id)

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .clean)
    }

    func testMultipleActiveSelectionChangesAreClean() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let third = item(start: 50, end: 60)
        let baseline = try snapshot(regions: [first, second, third], activeRegionID: first.id)
        let evaluator = AnthemRegionDirtyState(baseline: baseline)
        let selectingSecond = try snapshot(regions: [first, second, third], activeRegionID: second.id)
        let selectingThird = try snapshot(regions: [first, second, third], activeRegionID: third.id)
        let selectingFirst = try snapshot(regions: [first, second, third], activeRegionID: first.id)

        XCTAssertEqual(evaluator.evaluate(current: selectingSecond), .clean)
        XCTAssertEqual(evaluator.evaluate(current: selectingThird), .clean)
        XCTAssertEqual(evaluator.evaluate(current: selectingFirst), .clean)
    }

    func testStartChangeIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: id, start: 11, end: 20)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testEndChangeIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: id, start: 10, end: 21)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testAddedRegionIsDirty() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first])
        let current = try snapshot(regions: [first, second], activeRegionID: first.id)

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testDeletedRegionIsDirty() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [first])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testUUIDChangeIsDirty() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testRegionOrderChangeIsDirty() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [second, first], activeRegionID: first.id)

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testIncompleteRegionStartAndEndChangesAreDirty() throws {
        let startOnlyID = UUID()
        let endOnlyID = UUID()
        let startOnlyBaseline = try snapshot(regions: [item(id: startOnlyID, start: 10)])
        let startOnlyCurrent = try snapshot(regions: [item(id: startOnlyID, start: 11)])
        let endOnlyBaseline = try snapshot(regions: [item(id: endOnlyID, end: 20)])
        let endOnlyCurrent = try snapshot(regions: [item(id: endOnlyID, end: 21)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: startOnlyBaseline).evaluate(current: startOnlyCurrent), .dirty)
        XCTAssertEqual(AnthemRegionDirtyState(baseline: endOnlyBaseline).evaluate(current: endOnlyCurrent), .dirty)
    }

    func testCompleteRegionBecomingIncompleteIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: id, start: 10)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testIncompleteRegionBecomingCompleteIsDirty() throws {
        let id = UUID()
        let baseline = try snapshot(regions: [item(id: id, start: 10)])
        let current = try snapshot(regions: [item(id: id, start: 10, end: 20)])

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .dirty)
    }

    func testExactContentRevertIsClean() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let changed = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])
        let evaluator = AnthemRegionDirtyState(baseline: baseline)

        XCTAssertEqual(evaluator.evaluate(current: changed), .dirty)
        XCTAssertEqual(evaluator.evaluate(current: baseline), .clean)
    }

    func testBaselineSnapshotIsNotMutated() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let before = baseline
        let current = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])

        _ = AnthemRegionDirtyState(baseline: baseline).evaluate(current: current)

        XCTAssertEqual(baseline, before)
    }

    func testCurrentSnapshotIsNotMutated() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(id: baseline.regions[0].id, start: 11, end: 20)])
        let before = current

        _ = AnthemRegionDirtyState(baseline: baseline).evaluate(current: current)

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

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .clean)
    }

    func testEvaluationIgnoresDifferentActiveIDs() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [first, second], activeRegionID: second.id)

        XCTAssertEqual(AnthemRegionDirtyState(baseline: baseline).evaluate(current: current), .clean)
    }

    func testEvaluationDependsOnlyOnSnapshotContent() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let evaluator = AnthemRegionDirtyState(baseline: baseline)

        XCTAssertEqual(evaluator.evaluate(current: baseline), .clean)
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
