//
//  ViewModel.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Combine
import AVFoundation
import Accelerate
import AppKit

extension ViewModel.AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .edit:
            return "Can't edit file."
        case .formatMismatch:
            return "Can't paste: Format mismatch."
        case .read:
            return "Can't read file."
        }
    }
}

class ViewModel: ObservableObject {
    
    var acceptableUTITypes: [String] {
        ["public.mp3", "com.apple.m4a-audio", "com.microsoft.waveform-audio"]
    }
    
    let player = AudioPlayer()
    
    var pcmBuffer: AVAudioPCMBuffer?
    var amps: [Float] = []
    
    enum State {
        case empty, processing, ready
    }
    enum AppError: Error {
        case edit
        case formatMismatch
        case read
    }
    
    @Published var selectedTimeRange: Range<TimeInterval>?
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var highlighted = false
    @Published var state: State = .empty
    
    var duration: TimeInterval {
        pcmBuffer?.duration ?? TimeInterval(0)
    }
    
    var visibleDur: TimeInterval {
        visibleTimeRange.upperBound - visibleTimeRange.lowerBound
    }
    
    private let serviceQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    @Published var error: Error?
    
    var undoManager: UndoManager?
    
    var status: String? {
        guard let pcmBuffer = pcmBuffer else { return nil }
        return "\(pcmBuffer.sampleRate / Double(1000)) kHz  |  \(pcmBuffer.channelCount == 1 ? "Mono" : "Stereo")  |  \(pcmBuffer.duration.mmss())"
    }
    
    // MARK: - Undo / Redo Operations
    func delete(start: TimeInterval, end: TimeInterval) {
        let edited = pcmBuffer?.remove(startTime: start, endTime: end)
        guard let removed = pcmBuffer?.extract(from: start, to: end) else {
            self.error = AppError.edit
            return
        }
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.paste(buffer: removed, at: start)
        }
        undoManager?.setActionName("Delete")
        
        pcmBuffer = edited
        amps = edited?.compressed() ?? []
        state = .ready
        selectedTimeRange = nil
        visibleTimeRange = visibleTimeRange.clamped(to: 0.0..<(edited?.duration ?? 0.0))
    }
    
    func paste(buffer: AVAudioPCMBuffer, at time: TimeInterval) {
        if let pcmBuffer = pcmBuffer, buffer.format != pcmBuffer.format {
            self.error = AppError.formatMismatch
            return
        }
        
        let edited = pcmBuffer?.paste(buffer: buffer, at: time) ?? buffer
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.delete(start: time, end: time + buffer.duration)
        }
        undoManager?.setActionName("Paste")
        
        pcmBuffer = edited
        amps = edited.compressed()
        selectedTimeRange = time ..< (time + buffer.duration)
        if visibleTimeRange.isEmpty, let selectedTimeRange = selectedTimeRange {
            visibleTimeRange = selectedTimeRange
        }
        state = .ready
    }
    
    func copy() {
        guard let selectedTimeRange = selectedTimeRange,
              let pcmBuffer = pcmBuffer else { return }
        
        state = .processing
        serviceQueue.addOperation {
            defer {
                self.state = .ready
            }
            guard let buffer = pcmBuffer.extract(from: selectedTimeRange.lowerBound, to: selectedTimeRange.upperBound) else {
                self.error = AppError.edit
                return
            }
            
            do {
                try buffer.copy(to: NSPasteboard.general)
            } catch {
                self.error = error
            }
        }
    }
    
    func paste() {
        do {
            guard let buffer = try AVAudioPCMBuffer.read(from: NSPasteboard.general) else {
                throw AppError.edit
            }
            stop()
            state = .processing
            serviceQueue.addOperation {
                self.paste(buffer: buffer, at: self.player.currentTime)
                self.state = .ready
            }
            
        } catch {
            self.error = error
            return
        }
    }
    
    func cut() {
        copy()
        delete()
    }
    
    func delete() {
        guard let selectedTimeRange = selectedTimeRange else { return }
        stop()
        state = .processing
        serviceQueue.addOperation {
            self.delete(start: selectedTimeRange.lowerBound, end: selectedTimeRange.upperBound)
            self.state = .ready
        }
    }
    
    func seek(to time: TimeInterval) {
        let wasPlaying = player.state == .playing
        if wasPlaying {
            stop()
        }
        player.currentTime = time.clamped(to: 0.0...duration)
        if wasPlaying {
            play()
        }
    }
    
    func play() {
        switch player.state {
        case .playing:
            stop()
            
        case .stopped:
            guard let pcmBuffer = pcmBuffer else { return }
            play(buffer: pcmBuffer)
        }
    }
    func stop() {
        player.stop()
    }
    func forward() {
        selectedTimeRange = nil
        seek(to: player.currentTime + TimeInterval(15))
    }
    func forwardEnd() {
        selectedTimeRange = nil
        seek(to: duration)
    }
    func backward() {
        selectedTimeRange = nil
        seek(to: player.currentTime - TimeInterval(15))
    }
    func backwardEnd() {
        selectedTimeRange = nil
        seek(to: TimeInterval(0))
    }
    
    public func power(at time: TimeInterval) -> Float {
        guard let pcmBuffer = pcmBuffer else { return 0 }
        let sampleRate = Double(amps.count) / pcmBuffer.duration
        
        let index = Int(time * sampleRate)
        
        guard amps.indices.contains(index) else { return .zero }
        
        let power = amps[index]
        
        let avgPower = 20 * log10(power)
        
        return scaledPower(power: avgPower)
    }
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return 0.0
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return 0.0
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
    
    func play(buffer: AVAudioPCMBuffer) {
        if player.currentTime >= buffer.duration {
            player.currentTime = 0.0
        }
        if player.currentTime < 0.0 {
            player.currentTime = 0.0
        }
        
        do {
            if let selectedTimeRange = selectedTimeRange {
                guard let segment = buffer.extract(from: selectedTimeRange.lowerBound, to: selectedTimeRange.upperBound) else {
                    self.error = AppError.edit
                    return
                }
                
                try player.play(buffer: segment)
                
            } else {
                if player.currentTime == .zero {
                    try player.play(buffer: buffer)
                    
                } else {
                    guard player.currentTime < buffer.duration,
                          let segment = buffer.extract(from: player.currentTime, to: buffer.duration)
                    else {
                        self.error = AppError.edit
                        return
                    }
                    
                    try player.play(buffer: segment)
                }
            }
        } catch {
            self.error = error
        }
    }
    
    func readAudioFile(at url: URL) {
        stop()
        state = .processing
        
        serviceQueue.addOperation {
            defer {
                self.state = .ready
            }
            do {
                self.pcmBuffer = try AVAudioPCMBuffer(url: url)
                
                if let buffer = self.pcmBuffer {
                    
                    self.amps = buffer.compressed()
                    self.visibleTimeRange = 0.0 ..< buffer.duration
                    self.selectedTimeRange = nil
                    self.player.currentTime = 0.0
                    
                } else {
                    self.error = AppError.read
                }
                
            } catch {
                self.error = error
            }
        }
    }
}
