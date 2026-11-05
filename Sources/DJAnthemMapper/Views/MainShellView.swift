import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum AnthemDestination: String, CaseIterable, Identifiable {
    case library = "Library", importMedia = "Import", analysis = "Track Analysis"
    case anthemMap = "Anthem Map", playlists = "Playlists", settings = "Settings"
    var id: Self { self }
    var icon: String {
        switch self {
        case .library: return "music.note.list"
        case .importMedia: return "square.and.arrow.down"
        case .analysis: return "waveform.path.ecg"
        case .anthemMap: return "map"
        case .playlists: return "music.note.house"
        case .settings: return "gearshape"
        }
    }
}

struct MainShellView: View {
    @State private var selection: AnthemDestination = .importMedia
    @State private var media: MediaDescription?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var selectedAudioStreamID: Int?
    @StateObject private var playback = PlaybackController()

    var body: some View {
        HStack(spacing: 0) {
            AnthemSidebar(selection: $selection)
            Rectangle().fill(AnthemTheme.divider).frame(width: 1)
            workspace
            Rectangle().fill(AnthemTheme.divider).frame(width: 1)
            AnthemInspector(media: media, selectedAudioStreamID: $selectedAudioStreamID)
        }
        .frame(minWidth: AnthemLayout.minimumWindowWidth, minHeight: AnthemLayout.minimumWindowHeight)
        .background(AnthemTheme.background)
    }

    @ViewBuilder private var workspace: some View {
        switch selection {
        case .importMedia:
            ScrollView(.vertical, showsIndicators: true) {
                ImportWorkspace(media: $media, isImporting: $isImporting, importError: $importError, selectedAudioStreamID: $selectedAudioStreamID, playback: playback)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .library: PlaceholderWorkspace(title: "Library", subtitle: "Your imported music will appear here.", icon: "music.note.list")
        case .analysis: PlaceholderWorkspace(title: "Track Analysis", subtitle: "Audio analysis will appear here.", icon: "waveform.path.ecg")
        case .anthemMap: PlaceholderWorkspace(title: "Anthem Map", subtitle: "Analyse a track to build its Anthem Map.", icon: "map")
        case .playlists: PlaceholderWorkspace(title: "Playlists", subtitle: "Playlist organisation will appear here.", icon: "music.note.house")
        case .settings: PlaceholderWorkspace(title: "Settings", subtitle: "DJ Anthem Mapper preferences.", icon: "gearshape")
        }
    }
}

struct AnthemSidebar: View {
    @Binding var selection: AnthemDestination
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("MUSIC"); button(.library); button(.importMedia)
            heading("ANALYSIS").padding(.top, AnthemSpacing.medium)
            button(.analysis); button(.anthemMap); button(.playlists)
            Spacer(); heading("SYSTEM"); button(.settings)
        }
        .padding(.horizontal, 10).padding(.top, 16).padding(.bottom, 16)
        .frame(width: AnthemLayout.sidebarWidth, alignment: .topLeading).background(AnthemTheme.sidebar)
    }
    private func heading(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .bold)).tracking(1.2)
            .foregroundStyle(AnthemTheme.textMuted).padding(.horizontal, 12).padding(.vertical, 8)
    }
    private func button(_ destination: AnthemDestination) -> some View {
        Button { selection = destination } label: {
            HStack(spacing: 8) { Image(systemName: destination.icon).frame(width: 18); Text(destination.rawValue); Spacer() }
                .foregroundStyle(selection == destination ? AnthemTheme.textPrimary : AnthemTheme.textSecondary)
                .padding(.horizontal, 12).frame(height: AnthemLayout.navigationRowHeight)
                .background { if selection == destination { RoundedRectangle(cornerRadius: AnthemLayout.navigationCornerRadius).fill(AnthemTheme.navigationSelected) } }
        }.buttonStyle(.plain)
    }
}

struct ImportWorkspace: View {
    @StateObject private var anthemRegion = AnthemRegionController()
    @StateObject private var keyboardContext = EditorKeyboardContext()
    @StateObject private var saveCoordinator = AnthemMapSaveCoordinator()
    @State private var saveStatusMessage: String?
    @State private var anthemMapSession: AnthemMapSession?
    private let existingSaveCoordinator = AnthemMapExistingSaveCoordinator()
    private let saveAsCoordinator = AnthemMapSaveAsCoordinator()
    private let changeTrackProtectionCoordinator = AnthemMapChangeTrackProtectionCoordinator()
    @State private var isChangeTrackResolutionPresented = false
    private let openProtectionCoordinator = AnthemMapOpenProtectionCoordinator()
    @State private var isOpenResolutionPresented = false
    // M3_03H_OPEN_ANTHEM_MAP_UI_INTEGRATION
    @StateObject private var openCoordinator = AnthemMapOpenCoordinator()
    @State private var openStatusMessage: String?
    private let savePanelPresenter = AnthemMapSavePanelPresenter()
    private let saveExecutor = AnthemMapSaveExecutor()
    private let openPanelPresenter = AnthemMapOpenPanelPresenter()
    private let loadedMediaIdentityBuilder = AnthemMapLoadedMediaIdentityBuilder()
    @Binding var media: MediaDescription?
    @Binding var isImporting: Bool
    @Binding var importError: String?
    @Binding var selectedAudioStreamID: Int?
    @ObservedObject var playback: PlaybackController
    @State private var preparedMKVStreamID: Int?
    @State private var pendingMKVRestoreTime: TimeInterval?
    @State private var resumeMKVAfterSwitch = false
    @State private var waveformSamples: [Float] = []
    @State private var waveformIsLoading = false
    @State private var waveformError: String?
    @State private var waveformGeneration = 0
    private let importer = FFprobeMediaImporter()

    var body: some View {
        VStack(alignment: .leading, spacing: AnthemSpacing.section) {
            Text((media == nil ? "Import" : "")).font(AnthemTypography.trackTitle).foregroundStyle(AnthemTheme.textPrimary)
            Text((media == nil ? "Choose a track for DJ Anthem Mapper." : "")).foregroundStyle(AnthemTheme.textSecondary)
            Rectangle().fill(AnthemTheme.divider).frame(height: 1)
            Spacer()
            VStack(spacing: AnthemSpacing.standard) {
                Group { if media == nil { Image(systemName: "waveform.and.magnifyingglass") } }.font(.system(size: 58)).foregroundStyle(AnthemTheme.waveformBright)
                Text(isImporting ? "Analysing media…" : (media == nil ? "Import a Track" : "")).font(.title2.bold()).foregroundStyle(AnthemTheme.textPrimary)
                Text((media == nil ? "MP3 · M4A · MP4 · MKV · WAV" : "")).foregroundStyle(AnthemTheme.textSecondary)
                if isImporting { ProgressView().controlSize(.small) }
                if media == nil {
                    Button { chooseAudio() } label: {
                        Label("Choose Audio File…", systemImage: "square.and.arrow.down").padding(.horizontal, 18).frame(height: 38)
                    }.buttonStyle(.borderedProminent).tint(AnthemTheme.actionBlue).disabled(isImporting)
                }
                // M3_02B9_UI_SAVE_INTEGRATION
                if media != nil {
                    HStack(spacing: AnthemSpacing.small) {
                        Button { chooseAudio() } label: {
                            Label("Change Track…", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AnthemTheme.actionBlue)
                        .disabled(isImporting)
                        Button { openAnthemMap() } label: {
                            Label("Open Anthem Map…", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isImporting || playback.duration <= 0)
                        Button { saveAnthemMap() } label: {
                            Label("Save Anthem Map…", systemImage: "square.and.arrow.down.on.square")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!saveEligibility.canSave || isImporting)
                        Button { saveAnthemMapAs() } label: {
                            Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!saveEligibility.canSave || isImporting)
                    }
                }
                if openStatusMessage != nil || saveStatusMessage != nil {
                    HStack(spacing: AnthemSpacing.small) {
                        if let openStatusMessage {
                            Text(openStatusMessage)
                        }
                        if let saveStatusMessage {
                            Text(saveStatusMessage)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(AnthemTheme.textSecondary)
                }
                if let media { Text(media.sourceURL.lastPathComponent).foregroundStyle(AnthemTheme.textPrimary).padding(.top, 8) }
                if let importError { Text(importError).foregroundStyle(.red).multilineTextAlignment(.center).frame(maxWidth: 520) }
                if media != nil, playback.state != .idle {
                    PlaybackTransportView(playback: playback)
                        .frame(maxWidth: 680)
                        .padding(.top, AnthemSpacing.medium)
                    PrecisionSeekView(playback: playback, keyboardContext: keyboardContext)

                    EditorSpaceShortcutButton(context: keyboardContext, playback: playback)
                        .frame(width: 1, height: 1)
                        .frame(maxWidth: 760)
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.035))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AnthemTheme.border, lineWidth: 1)
                        }
                    AnthemRegionControlsView(controller: anthemRegion, playback: playback)
                        .frame(maxWidth: 920)

                    ZoomableWaveformTimelineView(
                        samples: waveformSamples,
                        isLoading: waveformIsLoading,
                        errorMessage: waveformError,
                        playback: playback,
                        anthemRegion: anthemRegion
                    )
                    .frame(maxWidth: 760)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Spacer()
        }
        // PHASE_4A3A4_WORKSPACE_HIT_TEST_FOCUS_RELEASE
        .background {
            Color.clear
                .contentShape(.interaction, Rectangle())
                .onTapGesture {
                    keyboardContext.requestFocusRelease()
                }
        }

        .padding(AnthemSpacing.workspace)
        .background(AnthemTheme.workspaceGradient)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            return importDroppedFile(url)
        }
        .confirmationDialog(
            "Save changes before changing track?",
            isPresented: $isChangeTrackResolutionPresented,
            titleVisibility: .visible
        ) {
            Button("Save") {
                resolvePendingChangeTrack(choice: .save)
            }
            Button("Discard Changes", role: .destructive) {
                resolvePendingChangeTrack(choice: .discard)
            }
            Button("Cancel", role: .cancel) {
                resolvePendingChangeTrack(choice: .cancel)
            }
        } message: {
            Text("The current Anthem Map contains unsaved changes.")
        }
        .confirmationDialog(
            "Save changes before opening another Anthem Map?",
            isPresented: $isOpenResolutionPresented,
            titleVisibility: .visible
        ) {
            Button("Save") {
                resolvePendingOpen(choice: .save)
            }
            Button("Discard Changes", role: .destructive) {
                resolvePendingOpen(choice: .discard)
            }
            Button("Cancel", role: .cancel) {
                resolvePendingOpen(choice: .cancel)
            }
        } message: {
            Text("The current Anthem Map contains unsaved changes.")
        }
        .onChange(of: selectedAudioStreamID) { _, newStreamID in
            guard let media,
                  media.sourceURL.pathExtension.lowercased() == "mkv",
                  newStreamID != preparedMKVStreamID else { return }
            generateWaveform(for: media, streamID: newStreamID)
            pendingMKVRestoreTime = playback.currentTime
            resumeMKVAfterSwitch = playback.isPlaying
            if resumeMKVAfterSwitch {
                playback.fadeOutForStreamSwitch(duration: 0.25) {
                    preparePlayback(for: media, streamID: newStreamID)
                }
            } else {
                preparePlayback(for: media, streamID: newStreamID)
            }
        }
    }

    private func generateWaveform(for media: MediaDescription, streamID: Int?) {
        waveformGeneration += 1
        let generation = waveformGeneration
        waveformSamples = []
        waveformError = nil
        waveformIsLoading = true
        let streamIndex = media.sourceURL.pathExtension.lowercased() == "mkv" ? streamID : nil
        WaveformAnalyser.analyse(
            sourceURL: media.sourceURL,
            absoluteStreamIndex: streamIndex,
            targetColumns: 60_000
        ) { result in
            guard generation == waveformGeneration else { return }
            waveformIsLoading = false
            switch result {
            case .success(let samples): waveformSamples = samples
            case .failure(let error): waveformError = error.localizedDescription
            }
        }
    }

    private func preparePlayback(for media: MediaDescription, streamID: Int?) {
        let fileExtension = media.sourceURL.pathExtension.lowercased()
        let nativeFormats = ["mp3", "m4a", "mp4", "wav"]

        if nativeFormats.contains(fileExtension) {
            preparedMKVStreamID = nil
            playback.prepare(url: media.sourceURL)
            return
        }

        guard fileExtension == "mkv" else {
            preparedMKVStreamID = nil
            playback.reset()
            return
        }

        guard let selectedStream = media.audioStreams.first(where: { $0.id == streamID })
                ?? media.defaultAudioStream else {
            playback.failExternalPreparation("No MKV audio stream is selected.")
            return
        }

        preparedMKVStreamID = selectedStream.id
        playback.beginExternalPreparation()
        MKVPlaybackPreparer.prepare(
            sourceURL: media.sourceURL,
            absoluteStreamIndex: selectedStream.id
        ) { result in
            guard selectedAudioStreamID == selectedStream.id else { return }
            switch result {
            case .success(let playbackURL):
                let restoreTime = pendingMKVRestoreTime
                let shouldResume = resumeMKVAfterSwitch
                pendingMKVRestoreTime = nil
                resumeMKVAfterSwitch = false
                playback.prepare(url: playbackURL)
                playback.whenReady {
                    if let restoreTime {
                        playback.seek(to: restoreTime) {
                            if shouldResume {
                                playback.fadeInAfterStreamSwitch(duration: 0.25)
                            }
                        }
                    } else if shouldResume {
                        playback.fadeInAfterStreamSwitch(duration: 0.25)
                    }
                }
            case .failure(let error):
                pendingMKVRestoreTime = nil
                resumeMKVAfterSwitch = false
                playback.failExternalPreparation(error.localizedDescription)
            }
        }
    }

    private func importDroppedFile(_ url: URL) -> Bool {
        let supported = ["mp3", "m4a", "mp4", "mkv", "wav"]
        guard url.isFileURL, supported.contains(url.pathExtension.lowercased()) else {
            importError = "Drop an MP3, M4A, MP4, MKV or WAV media file."
            return false
        }
        startImport(url)
        return true
    }

    private var hasUnsavedNewWorkspaceContent: Bool {
        let items = anthemRegion.collection.regions
        return !(items.count == 1 && items[0].region.isEmpty)
    }

    private func requestProtectedChangeTrack(to replacementURL: URL) {
        guard media != nil else {
            startImport(replacementURL)
            return
        }

        switch changeTrackProtectionCoordinator.requestChange(
            replacementURL: replacementURL,
            session: anthemMapSession,
            currentSnapshot: anthemRegion.captureSnapshot(),
            hasUnsavedNewWorkspaceContent: hasUnsavedNewWorkspaceContent,
            proceed: { @MainActor approvedURL in
                startImport(approvedURL)
            }
        ) {
        case .proceeded(let replacementSession):
            if let replacementSession {
                anthemMapSession = replacementSession
            }
        case .requiresResolution:
            isChangeTrackResolutionPresented = true
        case .blocked:
            break
        }
    }

    private func resolvePendingChangeTrack(choice: AnthemMapUnsavedChangeResolution.Choice) {
        guard let media else { return }

        isChangeTrackResolutionPresented = false
        changeTrackProtectionCoordinator.resolvePendingChange(
            choice: choice,
            session: anthemMapSession,
            currentSnapshot: anthemRegion.captureSnapshot(),
            mediaURL: media.sourceURL,
            trackDuration: playback.duration
        ) { result in
            if case .proceeded(let replacementSession) = result,
               let replacementSession {
                anthemMapSession = replacementSession
            }
        }
    }

    private func startImport(_ url: URL) {
        playback.reset()
        waveformGeneration += 1
        waveformSamples = []
        waveformIsLoading = false
        waveformError = nil
        preparedMKVStreamID = nil
        pendingMKVRestoreTime = nil
        resumeMKVAfterSwitch = false
        isImporting = true
        importError = nil
        media = nil
        selectedAudioStreamID = nil
        importer.inspect(url: url) { result in
            isImporting = false
            switch result {
            case .success(let description):
                anthemRegion.resetForNewTrack()
                anthemMapSession = nil
                media = description
                selectedAudioStreamID = description.defaultAudioStream?.id
                preparePlayback(for: description, streamID: selectedAudioStreamID)
                generateWaveform(for: description, streamID: selectedAudioStreamID)
            case .failure(let error): importError = error.localizedDescription
            }
        }
    }

    private func openAnthemMap() {
        do {
            let identity = try loadedMediaIdentityBuilder.makeIdentity(
                media: media,
                trackDuration: playback.duration
            )
            openPanelPresenter.present { result in
                switch result {
                case .selected(let mapURL):
                    requestProtectedOpen(to: mapURL, actualTrackIdentity: identity)
                case .cancelled:
                    break
                case .unavailable:
                    openStatusMessage = "DJ Anthem Mapper could not find its active window."
                }
            }
        } catch {
            openStatusMessage = "Load a playable track before opening an Anthem Map."
        }
    }

    private func requestProtectedOpen(
        to mapURL: URL,
        actualTrackIdentity: AnthemMapDocument.TrackIdentity
    ) {
        switch openProtectionCoordinator.requestOpen(
            mapURL: mapURL,
            session: anthemMapSession,
            currentSnapshot: anthemRegion.captureSnapshot(),
            hasUnsavedNewWorkspaceContent: hasUnsavedNewWorkspaceContent,
            proceed: { @MainActor approvedURL in
                performOpenAnthemMap(
                    at: approvedURL,
                    actualTrackIdentity: actualTrackIdentity
                )
            }
        ) {
        case .proceeded:
            break
        case .requiresResolution:
            isOpenResolutionPresented = true
        case .blocked:
            break
        }
    }

    private func resolvePendingOpen(choice: AnthemMapUnsavedChangeResolution.Choice) {
        guard let media else { return }

        isOpenResolutionPresented = false
        openProtectionCoordinator.resolvePendingOpen(
            choice: choice,
            session: anthemMapSession,
            currentSnapshot: anthemRegion.captureSnapshot(),
            mediaURL: media.sourceURL,
            trackDuration: playback.duration
        ) { result in
            if case .proceeded(let replacementSession) = result,
               let replacementSession {
                anthemMapSession = replacementSession
            }
        }
    }

    private func performOpenAnthemMap(
        at mapURL: URL,
        actualTrackIdentity: AnthemMapDocument.TrackIdentity
    ) {
        if openCoordinator.open(
            mapURL: mapURL,
            actualTrackIdentity: actualTrackIdentity,
            controller: anthemRegion
        ) {
            if let snapshot = anthemRegion.captureSnapshot() {
                anthemMapSession = AnthemMapSession(mapURL: mapURL, baseline: snapshot)
            }
            openStatusMessage = "Opened \(mapURL.lastPathComponent)"
        } else {
            openStatusMessage = openFailureMessage
        }
    }

    private var openFailureMessage: String {
        switch openCoordinator.status {
        case .failed(.trackMismatch):
            return "This Anthem Map does not match the loaded track."
        case .failed(.read):
            return "The Anthem Map could not be read."
        case .failed(.restoration), .failed(.controllerRestoreFailed):
            return "The Anthem Map could not be restored."
        case .idle, .opening, .opened:
            return "The Anthem Map could not be opened."
        }
    }
    private var saveEligibility: AnthemMapSaveEligibility {
        AnthemMapSaveEligibility.evaluate(
            hasLoadedMedia: media != nil,
            trackDuration: playback.duration,
            regions: anthemRegion.regions
        )
    }
    private func saveAnthemMap() {
        guard let media else {
            saveStatusMessage = "Load a track before saving an Anthem Map."
            return
        }
        guard let snapshot = anthemRegion.captureSnapshot() else {
            saveStatusMessage = "Anthem Map is not ready to save."
            return
        }
        guard let session = anthemMapSession, session.hasAssociatedMap else {
            saveAnthemMapAs()
            return
        }
        switch existingSaveCoordinator.save(
            session: session,
            mediaURL: media.sourceURL,
            trackDuration: playback.duration,
            currentSnapshot: snapshot
        ) {
        case .success(let success):
            anthemMapSession = success.session
            saveStatusMessage = "Saved \(success.session.mapURL?.lastPathComponent ?? "Anthem Map")"
        case .failure:
            saveStatusMessage = "Anthem Map is not ready to save."
        }
    }
    private func saveAnthemMapAs() {
        guard let media, let snapshot = anthemRegion.captureSnapshot() else {
            saveStatusMessage = "Anthem Map is not ready to save."
            return
        }
        saveAsCoordinator.saveAs(
            session: anthemMapSession,
            mediaURL: media.sourceURL,
            trackDuration: playback.duration,
            currentSnapshot: snapshot
        ) { result in
            switch result {
            case .saved(let success):
                anthemMapSession = success.session
                saveStatusMessage = "Saved \(success.session.mapURL?.lastPathComponent ?? "Anthem Map")"
            case .cancelled:
                break
            case .failed(.panelUnavailable):
                saveStatusMessage = "DJ Anthem Mapper could not find its active window."
            case .failed:
                saveStatusMessage = "Anthem Map is not ready to save."
            }
        }
    }
    private func chooseAudio() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.message = "Search for or choose an MP3, M4A, MP4, MKV or WAV file"
        panel.prompt = "Import"

        let supportedExtensions = ["mp3", "m4a", "mp4", "mkv", "wav"]
        panel.allowedContentTypes = supportedExtensions.compactMap { extensionName in
            UTType(filenameExtension: extensionName)
        }

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            importError = "DJ Anthem Mapper could not find its active window."
            return
        }

        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            let supported = ["mp3", "m4a", "mp4", "mkv", "wav"]
            guard supported.contains(url.pathExtension.lowercased()) else {
                importError = "Choose an MP3, M4A, MP4, MKV or WAV media file."
                return
            }
            requestProtectedChangeTrack(to: url)
        }
    }
}

struct PrecisionSeekView: View {
    @ObservedObject var playback: PlaybackController
    @ObservedObject var keyboardContext: EditorKeyboardContext
    @State private var minutesText = "00"
    @State private var secondsText = "00"
    @State private var millisecondsText = "000"
    @State private var validationMessage: String?
    @FocusState private var focusedField: TimeField?

    private enum TimeField: Hashable { case minutes, seconds, milliseconds }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                nudgeButton("−1s", delta: -1.0)
                nudgeButton("−100ms", delta: -0.1)
                nudgeButton("−10ms", delta: -0.01)

                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        fieldLabel("MIN", width: 58)
                        Text(":").foregroundStyle(AnthemTheme.textMuted)
                        fieldLabel("SEC", width: 58)
                        Text(".").foregroundStyle(AnthemTheme.textMuted)
                        fieldLabel("MS", width: 76)
                    }
                    HStack(spacing: 10) {
                        timeField($minutesText, field: .minutes, width: 58, digits: 2)
                        Text(":").font(.title3).foregroundStyle(AnthemTheme.textSecondary)
                        timeField($secondsText, field: .seconds, width: 58, digits: 2)
                        Text(".").font(.title3).foregroundStyle(AnthemTheme.textSecondary)
                        timeField($millisecondsText, field: .milliseconds, width: 76, digits: 3)
                    }
                }

                Button("Go") { applyFields() }
                    .buttonStyle(.borderedProminent)
                    .tint(AnthemTheme.actionBlue)
                    .disabled(!playback.canPlay)

                nudgeButton("+10ms", delta: 0.01)
                nudgeButton("+100ms", delta: 0.1)
                nudgeButton("+1s", delta: 1.0)
            }

            HStack {
                Text("Exact position")
                    .font(.caption)
                    .foregroundStyle(AnthemTheme.textMuted)
                Spacer()
                Text(formatPrecise(playback.currentTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AnthemTheme.anthemHighlight)
                Text("of \(formatPrecise(playback.duration))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AnthemTheme.textSecondary)
            }

            if let validationMessage {
                Text(validationMessage).font(.caption).foregroundStyle(.red)
            }
        }
        // PHASE_4A3A3_FOCUSSTATE_SOURCE_RELEASE
        .onChange(of: keyboardContext.focusReleaseGeneration) { _, _ in
            focusedField = nil
        }

        .onAppear { syncFields(to: playback.currentTime) }
        .onChange(of: playback.currentTime) { _, newValue in
            if focusedField == nil { syncFields(to: newValue) }
        }
        .onChange(of: focusedField) { _, newValue in
            keyboardContext.isEditingText = newValue != nil
        }
        .onDisappear {
            keyboardContext.isEditingText = false
        }
    }

    private func fieldLabel(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(AnthemTheme.textMuted)
            .frame(width: width)
    }

    private func timeField(_ value: Binding<String>, field: TimeField, width: CGFloat, digits: Int) -> some View {
        TextField("", text: value)
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .focused($focusedField, equals: field)
            .onChange(of: value.wrappedValue) { oldValue, newValue in
                let sanitised = PrecisionFieldInputSanitiser.sanitise(
                    oldValue: oldValue,
                    newValue: newValue,
                    maximumDigits: digits
                )
                if sanitised != newValue { value.wrappedValue = sanitised }
            }
            .onSubmit { applyFields() }
    }

    private func nudgeButton(_ title: String, delta: TimeInterval) -> some View {
        Button(title) {
            let target = clamped(playback.currentTime + delta)
            playback.seek(to: target)
            syncFields(to: target)
            validationMessage = nil
        }
        .buttonStyle(.bordered)
        .disabled(!playback.canPlay)
    }

    private func applyFields() {
        guard let minutes = Int(minutesText), minutes >= 0,
              let seconds = Int(secondsText), (0...59).contains(seconds),
              let milliseconds = Int(millisecondsText), (0...999).contains(milliseconds) else {
            validationMessage = "Use MIN 00+, SEC 00–59 and MS 000–999."
            return
        }
        let target = clamped(Double(minutes * 60 + seconds) + Double(milliseconds) / 1000.0)
        playback.seek(to: target)
        syncFields(to: target)
        validationMessage = nil
        focusedField = nil
    }

    private func syncFields(to seconds: TimeInterval) {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else {
            minutesText="00"; secondsText="00"; millisecondsText="000"; return
        }
        let totalMilliseconds = Int64((seconds * 1000).rounded())
        let ms = totalMilliseconds % 1000
        let totalSeconds = totalMilliseconds / 1000
        minutesText = String(format: "%02lld", totalSeconds / 60)
        secondsText = String(format: "%02lld", totalSeconds % 60)
        millisecondsText = String(format: "%03lld", ms)
    }

    private func clamped(_ seconds: TimeInterval) -> TimeInterval {
        // PHASE_4A2C_PRECISION_RANGE_VALIDATION
        guard seconds.isFinite else { return 0 }
        let lower = max(0, seconds)
        guard playback.duration.isFinite, playback.duration > 0 else { return lower }
        return min(playback.duration, lower)
    }

    private func formatPrecise(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "00:00.000" }
        let totalMilliseconds = Int64((seconds * 1000).rounded())
        return String(format: "%02lld:%02lld.%03lld", totalMilliseconds / 60000, (totalMilliseconds / 1000) % 60, totalMilliseconds % 1000)
    }
}

struct WaveformTimelineView: View {
    let samples: [Float]
    let isLoading: Bool
    let errorMessage: String?
    @ObservedObject var playback: PlaybackController

    private var progress: Double {
        guard playback.duration > 0 else { return 0 }
        return min(1, max(0, playback.currentTime / playback.duration))
    }

    var body: some View {
        VStack(spacing: AnthemSpacing.small) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(AnthemTheme.waveformBackground)
                    if isLoading {
                        ProgressView("Building waveform…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if samples.isEmpty {
                        Text("Waveform unavailable")
                            .font(.caption)
                            .foregroundStyle(AnthemTheme.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Canvas { context, size in
                            let midY = size.height / 2
                            let columnWidth = size.width / CGFloat(samples.count)
                            for (index, sample) in samples.enumerated() {
                                let height = max(1, CGFloat(sample) * (size.height - 12))
                                let x = CGFloat(index) * columnWidth
                                let rect = CGRect(x: x, y: midY - height / 2, width: max(1, columnWidth * 0.72), height: height)
                                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(AnthemTheme.waveformBright.opacity(0.88)))
                            }
                        }
                        Rectangle()
                            .fill(AnthemTheme.actionBlue.opacity(0.18))
                            .frame(width: geometry.size.width * progress)
                            .allowsHitTesting(false)
                        Rectangle()
                            .fill(AnthemTheme.anthemHighlight)
                            .frame(width: 2)
                            .offset(x: max(0, geometry.size.width * progress - 1))
                            .allowsHitTesting(false)
                    }
                }
                .overlay { RoundedRectangle(cornerRadius: 9).stroke(AnthemTheme.border, lineWidth: 1) }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        guard playback.duration > 0 else { return }
                        let ratio = min(1, max(0, value.location.x / max(1, geometry.size.width)))
                        playback.seek(to: playback.duration * ratio)
                    }
                )
            }
            .frame(height: 132)

            HStack {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AnthemTheme.textSecondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }
}

struct PlaybackTransportView: View {
    @ObservedObject var playback: PlaybackController
    @State private var dragTime: Double?

    private var displayedTime: Double { dragTime ?? playback.currentTime }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: AnthemSpacing.small) {
                Button { playback.skipBackward() } label: { Label("15", systemImage: "gobackward.15") }
                Button { playback.togglePlayback() } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(AnthemTheme.actionBlue)
                .disabled(!playback.canPlay)
                Button { playback.skipForward() } label: { Label("15", systemImage: "goforward.15") }
            }
            HStack(alignment: .bottom, spacing: 6) {
                VStack(spacing: 2) {
                    Text("MIN : SEC . MS")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.7)
                        .foregroundStyle(AnthemTheme.textMuted)
                    Text(formatTime(displayedTime))
                        .font(.system(.caption, design: .monospaced))
                }
                Slider(
                    value: Binding(
                        get: { displayedTime },
                        set: { dragTime = $0 }
                    ),
                    in: 0...max(playback.duration, 0.01),
                    onEditingChanged: { editing in
                        if !editing, let time = dragTime {
                            playback.seek(to: time)
                            dragTime = nil
                        }
                    }
                )
                .disabled(!playback.canPlay || playback.duration <= 0)
                VStack(spacing: 2) {
                    Text("MIN : SEC . MS")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.7)
                        .foregroundStyle(AnthemTheme.textMuted)
                    Text(formatTime(playback.duration))
                        .font(.system(.caption, design: .monospaced))
                }
            }
            if let message = playback.errorMessage {
                Text(message).foregroundStyle(.red).font(.caption).multilineTextAlignment(.center)
            } else {
                Text(playback.state.label).font(.caption).foregroundStyle(AnthemTheme.textSecondary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "00:00.000" }
        let totalMilliseconds = Int64((seconds * 1000).rounded())
        let milliseconds = totalMilliseconds % 1000
        let totalSeconds = totalMilliseconds / 1000
        let secondsPart = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        if totalMinutes >= 60 {
            return String(format: "%02lld:%02lld:%02lld.%03lld", totalMinutes / 60, totalMinutes % 60, secondsPart, milliseconds)
        }
        return String(format: "%02lld:%02lld.%03lld", totalMinutes, secondsPart, milliseconds)
    }
}

struct AnthemInspector: View {
    let media: MediaDescription?
    @Binding var selectedAudioStreamID: Int?
    private var selectedStream: AudioStreamDescription? {
        guard let media else { return nil }
        if let id = selectedAudioStreamID, let stream = media.audioStreams.first(where: { $0.id == id }) { return stream }
        return media.defaultAudioStream
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INSPECTOR").font(AnthemTypography.inspectorHeading).tracking(1.2).foregroundStyle(AnthemTheme.textMuted).padding(.bottom, 16)
            section("TRACK", trackText)
            section("AUDIO", audioText)
            if let media, media.audioStreams.count > 1 { streamSelector(media.audioStreams) }
            section("SOURCE", sourceText)
            section("ANALYSIS", "Not analysed")
            Spacer()
        }.padding(16).frame(width: AnthemLayout.inspectorWidth, alignment: .topLeading).background(AnthemTheme.inspector)
    }
    private var trackText: String {
        guard let media else { return "No track selected" }
        return [media.metadata.artist, media.metadata.title ?? media.sourceURL.deletingPathExtension().lastPathComponent].compactMap { $0 }.joined(separator: "\n")
    }
    private var audioText: String {
        guard let stream = selectedStream else { return "No media information" }
        var lines = [stream.codecName]
        if let rate = stream.sampleRate { lines.append("\(rate) Hz") }
        if let layout = stream.channelLayout { lines.append(layout.capitalized) }
        else if let channels = stream.channels { lines.append("\(channels) channels") }
        if let rate = stream.bitRate { lines.append(formatBitRate(rate)) }
        return lines.joined(separator: " · ")
    }
    private func streamSelector(_ streams: [AudioStreamDescription]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUDIO TRACK").font(AnthemTypography.inspectorLabel).tracking(1.1).foregroundStyle(AnthemTheme.textMuted)
            Picker("Audio Track", selection: $selectedAudioStreamID) {
                ForEach(streams) { stream in Text(streamLabel(stream)).tag(Optional(stream.id)) }
            }.labelsHidden().pickerStyle(.menu)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
         .overlay(alignment: .bottom) { Rectangle().fill(AnthemTheme.divider).frame(height: 1) }
    }
    private func streamLabel(_ stream: AudioStreamDescription) -> String {
        var parts=["#\(stream.id)"]
        if let x=stream.language, !x.isEmpty { parts.append(x.uppercased()) }
        if let x=stream.title, !x.isEmpty { parts.append(x) }
        parts.append(stream.codecName)
        if stream.isDefault { parts.append("Default") }
        return parts.joined(separator: " · ")
    }

    private var sourceText: String {
        guard let media else { return "No source selected" }
        let duration = media.duration.map(formatDuration) ?? "Unknown duration"
        return "\(media.container)\n\(duration)\n\(media.audioStreams.count) audio stream\(media.audioStreams.count == 1 ? "" : "s")\(media.hasVideo ? "" : "")"
    }
    private func section(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AnthemTypography.inspectorLabel).tracking(1.1).foregroundStyle(AnthemTheme.textMuted)
            Text(value).font(AnthemTypography.inspectorValue).foregroundStyle(AnthemTheme.textSecondary).lineLimit(6).truncationMode(.middle)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 13)
            .overlay(alignment: .bottom) { Rectangle().fill(AnthemTheme.divider).frame(height: 1) }
    }
    private func formatDuration(_ seconds: Double) -> String { let total = Int(seconds.rounded()); return String(format: "%d:%02d", total / 60, total % 60) }
    private func formatBitRate(_ value: Int) -> String { value >= 1000 ? "\(value / 1000) kb/s" : "\(value) b/s" }
}

struct PlaceholderWorkspace: View {
    let title: String; let subtitle: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: AnthemSpacing.section) {
            Text(title).font(AnthemTypography.trackTitle).foregroundStyle(AnthemTheme.textPrimary)
            Text(subtitle).foregroundStyle(AnthemTheme.textSecondary)
            Rectangle().fill(AnthemTheme.divider).frame(height: 1)
            Spacer(); Image(systemName: icon).font(.system(size: 60)).foregroundStyle(AnthemTheme.textMuted).frame(maxWidth: .infinity); Spacer()
        }.padding(AnthemSpacing.workspace).background(AnthemTheme.workspaceGradient)
    }
}
