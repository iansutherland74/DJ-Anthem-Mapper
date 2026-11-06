import XCTest
@testable import DJAnthemMapper
import Demucs

final class M404A2HTDemucsAPIProbeTests: XCTestCase {
    func testVocalConfigurationConstructsWithoutLoadingModel() {
        let model = HTDemucsVocalModelConfiguration.model
        _ = model
    }

    func testModelInventoryAPIIsReachableWithoutDownloadingWeights() {
        _ = allModels()
    }
}
