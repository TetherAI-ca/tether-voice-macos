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
            VoiceNotchContent(model: model)
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

    private var message: String {
        if model.isCapturingSpeech {
            return model.transcript.isEmpty ? "Listening…" : model.transcript
        }
        return model.headline == "Command stopped" ? model.detail : model.headline
    }

    private var needsMoreLines: Bool {
        !model.isCapturingSpeech && (model.needsClarification || model.headline == "Command stopped")
    }

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(needsMoreLines ? 3 : 1)
            // Show the newest spoken words when a command outgrows the single line.
            .truncationMode(model.isCapturingSpeech ? .head : .tail)
            .frame(width: 260)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 20)
            .accessibilityLabel(message)
            .help(message)
            .preferredColorScheme(.dark)
    }
}
