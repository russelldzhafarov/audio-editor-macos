//
//  EditorViewModel.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Combine
import AVFoundation
import Accelerate
import AppKit

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

class EditorViewModel: ObservableObject {
    
    let rulerHeight = CGFloat(32)
    
    var acceptableUTITypes: [String] {
        [AVFileType.mp3.rawValue,
         AVFileType.m4a.rawValue,
         AVFileType.wav.rawValue]
    }
    
    var fileURL: URL?
    var pcmBuffer: AVAudioPCMBuffer?
    var fileFormat: AVAudioFormat?
    var processingFormat: AVAudioFormat?
    
    var samples: [Float] = []
    
    enum State {
        case processing, ready
    }
    
    @Published var selectedTimeRange: ClosedRange<TimeInterval>?
    @Published var state: State = .ready
    
    var duration: TimeInterval {
        pcmBuffer?.duration ?? .zero
    }
    
    private let serviceQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    @Published var error: Error?
    
    var undoManager: UndoManager?
    
    enum PlayerState {
        case playing, stopped
    }
    
    @Published var playerState: PlayerState = .stopped
    @Published var currentTime: TimeInterval = .zero
    
    private let engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var timer: Timer?
    
    private var currentFrame: AVAudioFramePosition {
        guard
            let lastRenderTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime)
        else {
            return 0
        }
        
        return playerTime.sampleTime
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    var status: String? {
        guard let pcmBuffer = pcmBuffer else { return nil }
        return "\(pcmBuffer.sampleRate / Double(1000)) kHz  |  \(pcmBuffer.channelCount == 1 ? "Mono" : "Stereo")  |  \(pcmBuffer.duration.mmss())"
    }
    
    func selectAll() {
        selectedTimeRange = .zero ... duration
    }
    
    // MARK: - Undo / Redo Operations
    func delete(start: TimeInterval, end: TimeInterval) {
        let edited = pcmBuffer?.remove(startTime: start, endTime: end)
        guard let removed = pcmBuffer?.extract(from: start, to: end) else {
            self.error = AVError(.unknown)
            return
        }
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.paste(buffer: removed, at: start)
        }
        undoManager?.setActionName("Delete")
        
        pcmBuffer = edited
        samples = edited?.compressed() ?? []
        selectedTimeRange = nil
        
        state = .ready
    }
    
    func paste(buffer: AVAudioPCMBuffer, at time: TimeInterval) {
        if let pcmBuffer = pcmBuffer, buffer.format != pcmBuffer.format {
            // FIXME: Convert to current format
            self.error = AVError(.unknown)
            return
        }
        
        let edited = pcmBuffer?.paste(buffer: buffer, at: time) ?? buffer
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.delete(start: time, end: time + buffer.duration)
        }
        undoManager?.setActionName("Paste")
        
        pcmBuffer = edited
        samples = edited.compressed()
        selectedTimeRange = time ... (time + buffer.duration)
        
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
                self.error = AVError(.unknown)
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
                throw AVError(.unknown)
            }
            stop()
            state = .processing
            serviceQueue.addOperation {
                self.paste(buffer: buffer, at: self.currentTime)
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
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        currentTime = time.clamped(to: .zero ... duration)
        if wasPlaying {
            play()
        }
    }
    
    func play() {
        switch playerState {
        case .playing:
            stop()
            
        case .stopped:
            guard let pcmBuffer = pcmBuffer else { return }
            play(buffer: pcmBuffer)
        }
    }
    func stop() {
        playerNode.stop()
        engine.stop()
        
        timer?.invalidate()
        timer = nil
        
        playerState = .stopped
    }
    func forward() {
        selectedTimeRange = nil
        seek(to: currentTime + 15.0)
    }
    func forwardEnd() {
        selectedTimeRange = nil
        seek(to: duration)
    }
    func backward() {
        selectedTimeRange = nil
        seek(to: currentTime - 15.0)
    }
    func backwardEnd() {
        selectedTimeRange = nil
        seek(to: .zero)
    }
    
    func play(buffer: AVAudioPCMBuffer) {
        if currentTime >= buffer.duration {
            currentTime = .zero
        }
        if currentTime < .zero {
            currentTime = .zero
        }
        
        do {
            if let selectedTimeRange = selectedTimeRange {
                guard let segment = buffer.extract(from: selectedTimeRange.lowerBound, to: selectedTimeRange.upperBound) else {
                    self.error = AVError(.unknown)
                    return
                }
                
                try playBuffer(segment)
                
            } else {
                if currentTime == .zero {
                    try playBuffer(buffer)
                    
                } else {
                    guard currentTime < buffer.duration,
                          let segment = buffer.extract(from: currentTime, to: buffer.duration)
                    else {
                        self.error = AVError(.unknown)
                        return
                    }
                    
                    try playBuffer(segment)
                }
            }
        } catch {
            self.error = error
        }
    }
    
    func saveFile(to url: URL) {
        state = .processing
        serviceQueue.addOperation {
            defer {
                self.state = .ready
            }
            do {
                guard let pcmBuffer = self.pcmBuffer,
                      let fileFormat = self.fileFormat,
                      let processingFormat = self.processingFormat else { throw AVError(.unknown) }
                
                var settings = fileFormat.settings
                settings[AVFormatIDKey] = kAudioFormatMPEG4AAC
                
                let file = try AVAudioFile(forWriting: url,
                                           settings: settings,
                                           commonFormat: processingFormat.commonFormat,
                                           interleaved: processingFormat.isInterleaved)
                
                try file.write(from: pcmBuffer)
                
            } catch {
                self.error = error
            }
        }
    }
    
    func playBuffer(_ buffer: AVAudioPCMBuffer) throws {
        if !engine.isRunning {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
            engine.prepare()
            try engine.start()
            playerNode.play()
        }
        
        playerNode.scheduleBuffer(buffer)
        
        playerState = .playing
        
        let seekTime = currentTime
        let endTime = selectedTimeRange?.upperBound ?? duration
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(0.025), repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            
            strongSelf.currentTime = seekTime + (Double(strongSelf.currentFrame) / buffer.sampleRate)
            
            if strongSelf.currentTime >= endTime {
                strongSelf.stop()
            }
        }
        timer?.fire()
    }
}
