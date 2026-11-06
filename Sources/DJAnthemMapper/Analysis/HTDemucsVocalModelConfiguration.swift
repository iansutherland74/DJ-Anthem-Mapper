import Demucs

enum HTDemucsVocalModelConfiguration {
    static var model: DemucsModel {
        .fineTuned(stems: [.vocals])
    }
}
