import AppKit
import Combine
import DynamicNotchKit
import SwiftUI

/// Owns presentation only. Speech, command execution, and cancellation stay in AppModel.
@MainActor
final class VoiceNotchController {
    private enum PresentationState: Equatable {
        case hidden, expanded
    }

    private weak var model: AppModel?
    private let notch: DynamicNotch<VoiceNotchContent, EmptyView, EmptyView>
    private var hoverSubscription: AnyCancellable?
    private var transitionTask: Task<Void, Never>?
    private var dismissalTask: Task<Void, Never>?
    private var holdExpandedUntil: Date?
    private var requestedState: PresentationState = .hidden
    private var appliedState: PresentationState = .hidden
    private var isVisible = false
    private var isHovering = false

    init(model: AppModel) {
        self.model = model
        // No compact wings: the notch is hidden until a command or explicit Show.
        // Keep the same top-edge presentation on displays without a physical notch.
        notch = DynamicNotch(hoverBehavior: [.increaseShadow], style: .notch) {
            VoiceNotchContent(model: model, speech: model.speech)
        }
        hoverSubscription = notch.$isHovering.removeDuplicates().sink { [weak self] hovering in
            self?.hoverChanged(hovering)
        }
    }

    func show() {
        isVisible = true
        dismissalTask?.cancel()
        holdExpandedUntil = Date().addingTimeInterval(4)
        request(.expanded)
        scheduleDismissal(after: 4)
    }

    func setBusy(_ busy: Bool) {
        guard isVisible else { return }
        dismissalTask?.cancel()
        if busy {
            holdExpandedUntil = nil
            request(.expanded)
        } else {
            // Keep the result readable before hiding the notch completely.
            holdExpandedUntil = Date().addingTimeInterval(4)
            scheduleDismissal(after: 4)
        }
    }

    func hide() {
        isVisible = false
        isHovering = false
        dismissalTask?.cancel()
        holdExpandedUntil = nil
        request(.hidden)
    }

    func shutdown() {
        isVisible = false
        dismissalTask?.cancel()
        transitionTask?.cancel()
        hoverSubscription?.cancel()
        model?.systemAudio.stop()
        notch.windowController?.close()
    }

    private func hoverChanged(_ hovering: Bool) {
        isHovering = hovering
        guard isVisible else { return }
        dismissalTask?.cancel()
        if !hovering {
            scheduleDismissal(after: 0.6)
        }
    }

    private func scheduleDismissal(after seconds: Double) {
        dismissalTask?.cancel()
        guard model?.isBusy != true, model?.needsClarification != true else { return }
        let delay = max(seconds, holdExpandedUntil?.timeIntervalSinceNow ?? 0)
        dismissalTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard let self, self.isVisible, !self.isHovering,
                  self.model?.isBusy != true, self.model?.needsClarification != true else { return }
            self.hide()
        }
    }

    private func request(_ state: PresentationState) {
        requestedState = state
        if state == .expanded { model?.systemAudio.start() }
        else { model?.systemAudio.stop() }
        guard transitionTask == nil else { return }

        // Serialize the library's asynchronous transitions. A new request replaces
        // the destination, so a late dismissal cannot hide a newly started command.
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
                case .expanded:
                    guard let screen = self.preferredScreen else { return }
                    await self.notch.expand(on: screen)
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
                    else { model.hideVoiceNotch() }
                } label: {
                    Image(systemName: model.isBusy ? "stop.fill" : "chevron.up")
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                .accessibilityLabel(model.isBusy ? "Cancel current command" : "Hide voice notch")
                .help(model.isBusy ? "Cancel current command" : "Hide voice notch")
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
