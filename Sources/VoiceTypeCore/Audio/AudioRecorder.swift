import Foundation
@preconcurrency import AVFoundation

/// Records mono 16-bit PCM at 16 kHz from the default input and exposes
/// it as a WAV blob — the format every cloud STT accepts.
@MainActor
public final class AudioRecorder {
    public struct Recording: Sendable {
        public let audio: Data
        public let duration: TimeInterval
        public let sampleRate: Double
    }

    public enum RecorderError: LocalizedError {
        case alreadyRecording
        case notRecording
        case engineFailed(String)
        case noInputAvailable

        public var errorDescription: String? {
            switch self {
            case .alreadyRecording: return "Already recording."
            case .notRecording: return "No active recording."
            case .engineFailed(let m): return "Audio engine failed: \(m)"
            case .noInputAvailable: return "No microphone input is available."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat
    private let buffer: FrameBuffer
    private var converter: AVAudioConverter?
    private var startedAt: Date?

    private let targetSampleRate: Double = 16_000

    public init() {
        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            preconditionFailure("Failed to construct 16kHz mono Int16 PCM format — invariant violated.")
        }
        self.outputFormat = fmt
        self.buffer = FrameBuffer()
    }

    public var isRecording: Bool { engine.isRunning }

    public func start() async throws {
        if engine.isRunning { throw RecorderError.alreadyRecording }
        buffer.reset()
        startedAt = Date()

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else { throw RecorderError.noInputAvailable }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw RecorderError.engineFailed("Could not build sample-rate converter")
        }
        self.converter = converter

        let outFormat = outputFormat
        let targetRate = targetSampleRate
        let sink = buffer

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { tapBuffer, _ in
            // Real-time thread: encode + push into the lock-guarded buffer.
            // No Task hops, so we don't drop samples under load and the final
            // frames are available the instant stop() returns.
            guard let outBuffer = AVAudioPCMBuffer(
                pcmFormat: outFormat,
                frameCapacity: AVAudioFrameCount(targetRate)
            ) else { return }

            var error: NSError?
            var consumed = false
            let status = converter.convert(to: outBuffer, error: &error) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                consumed = true
                status.pointee = .haveData
                return tapBuffer
            }
            if status == .error || error != nil { return }

            guard let channelData = outBuffer.int16ChannelData else { return }
            let count = Int(outBuffer.frameLength)
            sink.append(pointer: channelData[0], count: count)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw RecorderError.engineFailed(error.localizedDescription)
        }
        AppLog.audio.info("Recording started at \(inputFormat.sampleRate, privacy: .public) Hz")
    }

    public func stop() async throws -> Recording {
        guard engine.isRunning else { throw RecorderError.notRecording }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        let duration: TimeInterval = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        startedAt = nil

        let frames = buffer.snapshotAndReset()
        let wav = WAVEncoder.encode(samples: frames, sampleRate: Int32(targetSampleRate))
        AppLog.audio.info("Recording stopped. frames=\(frames.count) bytes=\(wav.count) dur=\(duration, format: .fixed(precision: 2)) s")
        return Recording(audio: wav, duration: duration, sampleRate: targetSampleRate)
    }
}

/// Thread-safe Int16 sample buffer. Producer is the real-time audio tap;
/// consumer is the main actor on `stop()`.
final class FrameBuffer: @unchecked Sendable {
    private var frames: [Int16] = []
    private let lock = NSLock()

    func append(pointer: UnsafePointer<Int16>, count: Int) {
        guard count > 0 else { return }
        let chunk = UnsafeBufferPointer(start: pointer, count: count)
        lock.lock()
        frames.append(contentsOf: chunk)
        lock.unlock()
    }

    func snapshotAndReset() -> [Int16] {
        lock.lock()
        let copy = frames
        frames.removeAll(keepingCapacity: false)
        lock.unlock()
        return copy
    }

    func reset() {
        lock.lock()
        frames.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}

enum WAVEncoder {
    static func encode(samples: [Int16], sampleRate: Int32) -> Data {
        let byteRate = sampleRate * 2 // mono * 16-bit
        let dataLen = Int32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataLen

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(uint32LE: UInt32(bitPattern: chunkSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(uint32LE: 16)
        data.append(uint16LE: 1)       // PCM
        data.append(uint16LE: 1)       // mono
        data.append(uint32LE: UInt32(bitPattern: sampleRate))
        data.append(uint32LE: UInt32(bitPattern: byteRate))
        data.append(uint16LE: 2)       // block align
        data.append(uint16LE: 16)      // bits per sample
        data.append(contentsOf: Array("data".utf8))
        data.append(uint32LE: UInt32(bitPattern: dataLen))

        samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                data.append(UnsafeBufferPointer(start: UnsafeRawPointer(base).assumingMemoryBound(to: UInt8.self), count: samples.count * 2))
            }
        }
        return data
    }
}

private extension Data {
    mutating func append(uint16LE value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
    mutating func append(uint32LE value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }
}
