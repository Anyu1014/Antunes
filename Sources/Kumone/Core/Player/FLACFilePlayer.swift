import AVFoundation
import Foundation

/// 帧精确的本地 FLAC 播放器。
///
/// 为什么存在：`AVPlayer` / `AVAssetReader` 对 FLAC 的 seek 不按采样点定位
/// （实测：跳转后解出的音频与同位置的真实音频「平均绝对差」≈13000，完全不是
/// 同一段声音；同一文件的 `AVAudioFile` 按帧定位差值为 0）。所以无损 / Hi-Res /
/// 超清母带这类 `type == "flac"` 的源改走 `AVAudioEngine + AVAudioPlayerNode`，
/// 用 `scheduleSegment(startingFrame:)` 定位，进度由已渲染帧数得出。
@MainActor
final class FLACFilePlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var file: AVAudioFile?
    private var scheduleToken = UUID()
    private var startedAtFrame: AVAudioFramePosition = 0
    private var sampleRate: Double = 0
    private var pausedPosition: TimeInterval = 0
    private var volume: Float = 1

    var onEnded: (@MainActor () -> Void)?

    private(set) var isLoaded = false
    private(set) var isPlaying = false

    var duration: TimeInterval {
        guard let file, sampleRate > 0 else { return 0 }
        return Double(file.length) / sampleRate
    }

    init() {
        engine.attach(node)
    }

    // MARK: - Loading

    /// Points the player at a local file. `startAt` is honored by scheduling the
    /// segment from that exact frame, so the first sample heard is the one at
    /// `startAt` — no decode-side guessing involved.
    func load(url: URL, startAt: TimeInterval = 0, autoplay: Bool) throws {
        stop()
        let file = try AVAudioFile(forReading: url)
        self.file = file
        let format = file.processingFormat
        sampleRate = format.sampleRate
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        isLoaded = true
        schedule(at: startAt)
        if autoplay { play() } else { pausedPosition = startAt }
    }

    // MARK: - Transport

    func play() {
        guard isLoaded, let file else { return }
        if !engine.isRunning {
            try? engine.start()
        }
        if !node.isPlaying {
            // Resuming after a pause: the segment is still scheduled, just let
            // the node run again.
            if !pausedPosition.isZero || nodeTimeSample() != nil {
                node.play()
            } else {
                schedule(at: pausedPosition)
                node.play()
            }
        } else {
            node.play()
        }
        isPlaying = true
        _ = file
    }

    func pause() {
        guard isLoaded else { return }
        pausedPosition = position
        node.pause()
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        guard isLoaded else { return }
        let clamped = max(0, min(time, max(duration - 0.05, 0)))
        schedule(at: clamped)
        if isPlaying { node.play() } else { pausedPosition = clamped }
    }

    func stop() {
        scheduleToken = UUID()
        if node.isPlaying { node.stop() }
        node.reset()
        engine.stop()
        isLoaded = false
        isPlaying = false
        file = nil
        startedAtFrame = 0
        pausedPosition = 0
    }

    func setVolume(_ value: Float) {
        volume = value
        engine.mainMixerNode.outputVolume = value
    }

    /// Seconds into the track, from frames actually handed to the output.
    var position: TimeInterval {
        guard isLoaded, sampleRate > 0 else { return pausedPosition }
        guard node.isPlaying, let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else {
            return pausedPosition
        }
        let frames = AVAudioFramePosition(playerTime.sampleTime)
        return Double(startedAtFrame + max(0, frames)) / sampleRate
    }

    // MARK: - Private

    private func nodeTimeSample() -> AVAudioFramePosition? {
        guard node.isPlaying, let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else { return nil }
        return AVAudioFramePosition(playerTime.sampleTime)
    }

    private func schedule(at time: TimeInterval) {
        guard let file else { return }
        let startFrame = AVAudioFramePosition(max(0, time) * sampleRate)
        guard startFrame < file.length else { return }
        let remaining = AVAudioFrameCount(file.length - startFrame)
        let token = UUID()
        scheduleToken = token
        startedAtFrame = startFrame
        pausedPosition = time
        if node.isPlaying { node.stop() }
        node.scheduleSegment(file, startingFrame: startFrame, frameCount: remaining, at: nil) { [weak self] in
            Task { @MainActor in
                guard let self, self.scheduleToken == token else { return }
                self.isPlaying = false
                self.pausedPosition = self.duration
                self.onEnded?()
            }
        }
    }
}
