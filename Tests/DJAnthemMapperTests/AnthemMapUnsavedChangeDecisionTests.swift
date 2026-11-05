import Foundation
import XCTest
@testable import DJAnthemMapper

final class AnthemMapUnsavedChangeDecisionTests: XCTestCase {
    private let decision = AnthemMapUnsavedChangeDecision()

    func testExistingCleanSessionProceeds() throws {
        let snapshot = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(evaluate(session: session(baseline: snapshot), current: snapshot), .proceed)
    }

    func testExistingSessionWithChangedStartRequiresResolution() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .requiresResolution)
    }

    func testExistingSessionWithChangedEndRequiresResolution() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 10, end: 21, id: baseline.regions[0].id)])

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .requiresResolution)
    }

    func testExistingSessionWithAddedRegionRequiresResolution() throws {
        let first = item(start: 10, end: 20)
        let baseline = try snapshot(regions: [first])
        let current = try snapshot(regions: [first, item(start: 30, end: 40)])

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .requiresResolution)
    }

    func testExistingSessionWithDeletedRegionRequiresResolution() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second])
        let current = try snapshot(regions: [first])

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .requiresResolution)
    }

    func testExistingSessionWithChangedUUIDRequiresResolution() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .requiresResolution)
    }

    func testExistingSessionWithReorderedRegionsRequiresResolution() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second])
        let current = try snapshot(regions: [second, first], activeRegionID: first.id)

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .requiresResolution)
    }

    func testActiveRegionOnlyDifferenceProceeds() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let baseline = try snapshot(regions: [first, second], activeRegionID: first.id)
        let current = try snapshot(regions: [first, second], activeRegionID: second.id)

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .proceed)
    }

    func testMultipleActiveRegionChangesWithIdenticalRegionsProceed() throws {
        let first = item(start: 10, end: 20)
        let second = item(start: 30, end: 40)
        let third = item(start: 50, end: 60)
        let baseline = try snapshot(regions: [first, second, third], activeRegionID: first.id)
        let session = session(baseline: baseline)
        let selectingSecond = try snapshot(regions: [first, second, third], activeRegionID: second.id)
        let selectingThird = try snapshot(regions: [first, second, third], activeRegionID: third.id)

        XCTAssertEqual(evaluate(session: session, current: selectingSecond), .proceed)
        XCTAssertEqual(evaluate(session: session, current: selectingThird), .proceed)
    }

    func testEditedThenExactlyRevertedContentProceeds() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let changed = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let session = session(baseline: baseline)

        XCTAssertEqual(evaluate(session: session, current: changed), .requiresResolution)
        XCTAssertEqual(evaluate(session: session, current: baseline), .proceed)
    }

    func testNilSessionWithNoUnsavedNewWorkspaceContentProceeds() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(evaluate(session: nil, current: current), .proceed)
    }

    func testNilSessionWithUnsavedNewWorkspaceContentRequiresResolution() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(
            evaluate(session: nil, current: current, hasUnsavedNewWorkspaceContent: true),
            .requiresResolution
        )
    }

    func testNilSessionWithIncompleteRegionAndUnsavedContentRequiresResolution() throws {
        let current = try snapshot(regions: [item(start: 10, end: nil)])

        XCTAssertEqual(
            evaluate(session: nil, current: current, hasUnsavedNewWorkspaceContent: true),
            .requiresResolution
        )
    }

    func testNilSessionWithAddedRegionAndUnsavedContentRequiresResolution() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20), item(start: 30, end: 40)])

        XCTAssertEqual(
            evaluate(session: nil, current: current, hasUnsavedNewWorkspaceContent: true),
            .requiresResolution
        )
    }

    func testNilSessionWithDeletedRegionAndUnsavedContentRequiresResolution() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(
            evaluate(session: nil, current: current, hasUnsavedNewWorkspaceContent: true),
            .requiresResolution
        )
    }

    func testNilCurrentSnapshotWithExistingSessionRequiresResolution() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: nil), .requiresResolution)
    }

    func testNilCurrentSnapshotWithNilSessionAndNoContentFlagRequiresResolution() {
        XCTAssertEqual(evaluate(session: nil, current: nil), .requiresResolution)
    }

    func testNilCurrentSnapshotWithNilSessionAndUnsavedContentFlagRequiresResolution() {
        XCTAssertEqual(
            evaluate(session: nil, current: nil, hasUnsavedNewWorkspaceContent: true),
            .requiresResolution
        )
    }

    func testExistingCleanSessionIgnoresUnsavedNewWorkspaceContentFlag() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(
            evaluate(
                session: session(baseline: current),
                current: current,
                hasUnsavedNewWorkspaceContent: true
            ),
            .proceed
        )
    }

    func testExistingDirtySessionIgnoresNoContentFlag() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])

        XCTAssertEqual(
            evaluate(
                session: session(baseline: baseline),
                current: current,
                hasUnsavedNewWorkspaceContent: false
            ),
            .requiresResolution
        )
    }

    func testEvaluationDoesNotMutateSession() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let session = session(baseline: baseline)
        let before = session

        _ = evaluate(session: session, current: baseline)

        XCTAssertEqual(session, before)
    }

    func testEvaluationDoesNotMutateSnapshot() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])
        let before = current

        _ = evaluate(session: nil, current: current, hasUnsavedNewWorkspaceContent: true)

        XCTAssertEqual(current, before)
    }

    func testEvaluationIsDeterministic() throws {
        let baseline = try snapshot(regions: [item(start: 10, end: 20)])
        let current = try snapshot(regions: [item(start: 11, end: 20, id: baseline.regions[0].id)])
        let session = session(baseline: baseline)

        XCTAssertEqual(evaluate(session: session, current: current), evaluate(session: session, current: current))
    }

    func testEightRegionExistingSessionEvaluatesNormally() throws {
        let regions = (0..<8).map { index in
            item(start: TimeInterval(index * 10), end: TimeInterval(index * 10 + 5))
        }
        let baseline = try snapshot(regions: regions, activeRegionID: regions[0].id)
        let current = try snapshot(regions: regions, activeRegionID: regions[7].id)

        XCTAssertEqual(evaluate(session: session(baseline: baseline), current: current), .proceed)
    }

    func testEvaluationUsesOnlyPureValueInputs() throws {
        let current = try snapshot(regions: [item(start: 10, end: 20)])

        XCTAssertEqual(evaluate(session: nil, current: current), .proceed)
    }

    private func evaluate(
        session: AnthemMapSession?,
        current: AnthemRegionSnapshot?,
        hasUnsavedNewWorkspaceContent: Bool = false
    ) -> AnthemMapUnsavedChangeDecision.Outcome {
        decision.evaluate(
            session: session,
            currentSnapshot: current,
            hasUnsavedNewWorkspaceContent: hasUnsavedNewWorkspaceContent
        )
    }

    private func session(baseline: AnthemRegionSnapshot) -> AnthemMapSession {
        AnthemMapSession(mapURL: URL(fileURLWithPath: "/Maps/Set.anthemmap"), baseline: baseline)
    }

    private func snapshot(
        regions: [AnthemRegionItem],
        activeRegionID: UUID? = nil
    ) throws -> AnthemRegionSnapshot {
        try AnthemRegionSnapshot(regions: regions, activeRegionID: activeRegionID ?? regions[0].id)
    }

    private func item(
        start: TimeInterval?,
        end: TimeInterval?,
        id: UUID = UUID()
    ) -> AnthemRegionItem {
        AnthemRegionItem(id: id, region: AnthemRegion(start: start, end: end))
    }
}
