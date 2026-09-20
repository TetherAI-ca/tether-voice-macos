import AppKit
import Combine
import DynamicNotchKit
import SwiftUI

/// Owns presentation only. Speech, command execution, and cancellation stay in AppModel.
@MainActor
final class VoiceNotchController {
    private weak var model: AppModel?
    private let notch: DynamicNotch<VoiceNotchContent, VoiceNotchLeading, VoiceNotchTrailing>
    private var hoverSubscription: AnyCancellable?
    private var transitionTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var holdExpandedUntil: Date?
    private var requestedState: DynamicNotchState = .hidden
    private var appliedState: DynamicNotchState = .hidden
    private var isVisible = false
    private var isHovering = false
    private var ignoreHoverUntilExit = false

    init(model: AppModel) {
        self.model = model
        // Floating style hides on compact(). Notch style also supplies a top-edge
        // compact presentation on external displays through its menu-bar geometry.
        notch = DynamicNotch(hoverBehavior: [.increaseShadow], style: .notch) {
            VoiceNotchContent(model: model, speech: model.speech)
        } compactLeading: {
            VoiceNotchLeading(model: model)
        } compactTrailing: {
            VoiceNotchTrailing(model: model)
        }
        hoverSubscription = notch.$isHovering.removeDuplicates().sink { [weak self] hovering in
            self?.hoverChanged(hovering)
        }
    }

    func show(expanded: Bool) {
        isVisible = true
        ignoreHoverUntilExit = false
        collapseTask?.cancel()
        let expand = expanded || model?.isBusy == true || model?.needsClarification == true
        holdExpandedUntil = expand ? Date().addingTimeInterval(4) : nil
        request(expand ? .expanded : .compact)
        if expand { scheduleCollapse(after: 4) }
    }

    func setBusy(_ busy: Bool) {
        guard isVisible else { return }
        collapseTask?.cancel()
        if busy {
            holdExpandedUntil = nil
            request(.expanded)
        } else {
            // Keep the result readable before returning to the compact notch.
            holdExpandedUntil = Date().addingTimeInterval(4)
            scheduleCollapse(after: 4)
        }
    }

    func collapse() {
        guard isVisible, model?.isBusy != true else { return }
        collapseTask?.cancel()
        holdExpandedUntil = nil
        // Clicking the collapse button must not immediately expand it again.
        ignoreHoverUntilExit = isHovering
        request(.compact)
    }

    func hide() {
        isVisible = false
        isHovering = false
        ignoreHoverUntilExit = false
        collapseTask?.cancel()
        holdExpandedUntil = nil
        request(.hidden)
    }

    func shutdown() {
        isVisible = false
        collapseTask?.cancel()
        transitionTask?.cancel()
        hoverSubscription?.cancel()
        model?.systemAudio.stop()
        notch.windowController?.close()
    }

    private func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        guard isVisible else { return }
        if !hovering { ignoreHoverUntilExit = false }
        guard !ignoreHoverUntilExit else { return }
        collapseTask?.cancel()
        if hovering {
            request(.expanded)
        } else {
            scheduleCollapse(after: 0.6)
        }
    }

    private func scheduleCollapse(after seconds: Double) {
        collapseTask?.cancel()
        guard model?.isBusy != true, model?.needsClarification != true else { return }
        let delay = max(seconds, holdExpandedUntil?.timeIntervalSinceNow ?? 0)
        collapseTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard let self, self.isVisible, !self.isHovering,
                  self.model?.isBusy != true, self.model?.needsClarification != true else { return }
            self.request(.compact)
        }
    }

    private func request(_ state: DynamicNotchState) {
        requestedState = state
        if state == .expanded { model?.systemAudio.start() }
        else { model?.systemAudio.stop() }
        guard transitionTask == nil else { return }

        // Serialize the library's asynchronous transitions. A new request replaces
        // the destination, so a late collapse cannot hide a newly started command.
        transitionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.transitionTask = nil }
            while !Task.isCancelled, self.appliedState != self.requestedState {
                let state = self.requestedState
                let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                let animation: Animation = reduceMotion ? .linear(duration: 0) : .smooth(duration: 0.25)
                self.notch.transitionConfiguration = .init(
                    openingAnimation: animation,
                    closingAnimation: animation,
                    conversionAnimation: animation,
                    skipIntermediateHides: true
                )
                switch state {
                case .expanded, .compact:
                    guard let screen = self.preferredScreen else { return }
                    if state == .expanded { await self.notch.expand(on: screen) }
                    else { await self.notch.compact(on: screen) }
                    self.notch.windowController?.window?.hidesOnDeactivate = false
                    self.notch.windowController?.window?.collectionBehavior.insert(.fullScreenAuxiliary)
                case .hidden:
                    await self.notch.hide()
                }
                self.appliedState = state
            }
        }
    }

    private var preferredScreen: NSScreen? {
        // Match DynamicNotchKit's display-change handling, which uses the primary screen.
        NSScreen.screens.first
    }
}

private struct VoiceNotchLeading: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button { model.showVoiceNotch() } label: {
            Image(systemName: model.isBusy ? "waveform" : "waveform.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.teal)
                .frame(width: 40, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expand Tether Voice notch")
        .help("Show voice controls")
    }
}

private struct VoiceNotchTrailing: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button { model.showVoiceNotch() } label: {
            Text(model.isBusy ? "Busy" : "⌃⌥␣")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 40, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isBusy ? "Command in progress" : "Hold Control Option Space to speak")
        .help(model.headline)
    }
}

private struct VoiceNotchContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var speech: SpeechInput
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var field = PixelField(count: 720, bounds: CGSize(width: 320, height: 70))

    private var message: String {
        if speech.isListening { return model.transcript.isEmpty ? "Listening…" : model.transcript }
        return model.headline == "Command stopped" ? model.detail : model.headline
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24)).foregroundStyle(.teal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tether Voice").font(.system(size: 14, weight: .semibold))
                    Text(model.targetName).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button { model.showSettings() } label: {
                    Image(systemName: "gearshape").frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings and commands")
                .help("Settings and commands")
                Button {
                    if model.isBusy { model.cancel() }
                    else { model.collapseVoiceNotch() }
                } label: {
                    Image(systemName: model.isBusy ? "stop.fill" : "chevron.up")
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .accessibilityLabel(model.isBusy ? "Cancel current command" : "Collapse notch")
                .help(model.isBusy ? "Cancel current command" : "Collapse notch")
            }
            .buttonStyle(.plain)

            Group {
                if reduceMotion {
                    Text(model.word ?? "")
                        .font(.system(size: 34, weight: .heavy))
                        .minimumScaleFactor(0.3).lineLimit(1)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                        Canvas { context, _ in
                            let music = model.systemAudio.levels
                            if model.word == nil && !speech.isListening && music.isPlaying {
                                field.equalise(music.bands, at: timeline.date.timeIntervalSinceReferenceDate)
                            } else {
                                field.spell(model.word)
                            }
                            field.step(to: timeline.date.timeIntervalSinceReferenceDate, level: speech.isListening ? speech.audioLevel : 0)
                            field.draw(in: &context)
                        }
                    }
                }
            }
            .frame(width: 320, height: 70)
            .accessibilityHidden(true)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center).lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 36)
                .help(message)
            if !speech.isListening && !model.transcript.isEmpty {
                Text(model.transcript).font(.system(size: 11))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .lineLimit(2).help(model.transcript)
            }
            HStack {
                Text("⌃⌥Space").font(.system(size: 10, design: .monospaced))
                Text("Hold to speak").font(.system(size: 10))
                Spacer()
                if model.isBusy { Text("Esc to cancel").font(.system(size: 10)) }
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: 320)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}
