import SwiftUI
import Combine

/// Manages waveform bar levels and an internal display timer.
/// Lives as a reference type so the Timer closure always reads fresh state.
@MainActor
final class WaveformState: ObservableObject {
    @Published var levels: [CGFloat] = Array(repeating: 0.03, count: 40)

    /// The current audio level fed from the parent -- updated on every
    /// SwiftUI body evaluation so the timer always has the latest value.
    var currentAudioLevel: Float = 0

    private var phase: Double = 0
    private var timer: Timer?

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        levels = Array(repeating: 0.03, count: 40)
        phase = 0
    }

    private func tick() {
        phase += 0.15
        let base = CGFloat(currentAudioLevel)
        levels.removeFirst()
        let jitter = CGFloat.random(in: -0.06...0.06)
        let breathe = sin(phase) * 0.03
        let newLevel = max(0.03, min(1.0, base + jitter + breathe))
        levels.append(newLevel)
    }

    deinit {
        timer?.invalidate()
    }
}

struct WaveformView: View {
    var audioLevel: Float
    var isRecording: Bool
    var accentColor: Color = .primary

    @StateObject private var state = WaveformState()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(state.levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(barColor(for: level))
                    .frame(width: 2.5, height: max(2, level * 40))
            }
        }
        .frame(height: 40)
        .onChange(of: audioLevel) { _, newLevel in
            state.currentAudioLevel = newLevel
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                state.currentAudioLevel = audioLevel
                state.startTimer()
            } else {
                state.stopTimer()
                withAnimation(.easeOut(duration: 0.4)) {
                    state.reset()
                }
            }
        }
        .onAppear {
            state.currentAudioLevel = audioLevel
            if isRecording {
                state.startTimer()
            }
        }
        .onDisappear {
            state.stopTimer()
        }
    }

    private func barColor(for level: CGFloat) -> Color {
        let opacity = 0.25 + Double(level) * 0.75
        return accentColor.opacity(opacity)
    }
}
