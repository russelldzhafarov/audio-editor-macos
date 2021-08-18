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

class ViewModel: ObservableObject {
    
    var pcmBuffer: AVAudioPCMBuffer?
    var amps: [Float] = []
    
    enum PlayerState {
        case playing, stopped, paused
    }
    struct ReadAudioError: Error {
    }
    
    @Published var selectedTimeRange: Range<TimeInterval>?
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var highlighted = false
    @Published var loaded = false
    var looped = true
    
    var duration: TimeInterval {
        pcmBuffer?.duration ?? TimeInterval(0)
    }
    
    var visibleDur: TimeInterval {
        visibleTimeRange.upperBound - visibleTimeRange.lowerBound
    }
    
    private let audioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    
    private let serviceQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        return q
    }()
    
    @Published var error: Error?
    
    private var timer: Timer?
    
    private var currentFrame: AVAudioFramePosition {
        guard
            let lastRenderTime = audioPlayer.lastRenderTime,
            let playerTime = audioPlayer.playerTime(forNodeTime: lastRenderTime)
        else {
            return 0
        }
        
        return playerTime.sampleTime
    }
    
    @Published var playerState = PlayerState.stopped {
        didSet {
            switch playerState {
            case .playing:
                let seekTime = currentTime
                timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(0.025), repeats: true) { [weak self] _ in
                    guard let strongSelf = self,
                          let pcmBuffer = strongSelf.pcmBuffer else { return }
                    
                    strongSelf.currentTime = seekTime + (Double(strongSelf.currentFrame) / pcmBuffer.sampleRate)
                }
                
            case .paused, .stopped:
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    var status: String? {
        guard let pcmBuffer = pcmBuffer else { return nil }
        return "\(pcmBuffer.sampleRate / Double(1000)) kHz  |  \(pcmBuffer.channelCount == 1 ? "Mono" : "Stereo")  |  \(pcmBuffer.duration.mmss())"
    }
    
    // MARK: - Undo / Redo Operations
    @objc func delete(start: TimeInterval, end: TimeInterval) {
        guard let edited = pcmBuffer?.remove(startTime: start, endTime: end),
              let removed = pcmBuffer?.copy(timeRange: start..<end) else {
            self.error = EditError.delete
            return
        }
        
        undoManager.registerUndo(withTarget: self) { target in
            target.paste(buffer: removed, at: start)
        }
        undoManager.setActionName("Delete")
        
        pcmBuffer = edited
        amps = AudioService.compress(buffer: edited)
        state = .ready
        selectedTimeRange = nil
    }
    
    @objc func paste(buffer: AVAudioPCMBuffer, at time: TimeInterval) {
        guard let edited = pcmBuffer?.paste(buffer: buffer, at: time) else {
            self.error = EditError.delete
            return
        }
        
        undoManager.registerUndo(withTarget: self) { target in
            target.delete(start: time, end: time + buffer.duration)
        }
        undoManager.setActionName("Paste")
        
        pcmBuffer = edited
        amps = AudioService.compress(buffer: edited)
        state = .ready
        selectedTimeRange = time ..< (time + Double(buffer.frameLength) / buffer.sampleRate)
    }
    
    func seek(to time: TimeInterval) {
        let wasPlaying = playerState == .playing
        if wasPlaying {
            stop()
        }
        currentTime = time.clamped(to: 0.0...duration)
        if wasPlaying {
            play()
        }
    }
    
    func play() {
        switch playerState {
        case .playing:
            stop()
            
        case .paused, .stopped:
            guard let pcmBuffer = pcmBuffer else { return }
            play(buffer: pcmBuffer)
        }
    }
    func stop() {
        audioPlayer.stop()
        audioEngine.stop()
        playerState = .stopped
    }
    func forward() {
        selectedTimeRange = nil
        seek(to: currentTime + TimeInterval(15))
    }
    func forwardEnd() {
        selectedTimeRange = nil
        seek(to: duration)
    }
    func backward() {
        selectedTimeRange = nil
        seek(to: currentTime - TimeInterval(15))
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
    
    func readAudioFile(at url: URL) {
        state = .processing
        
        let op = ReadBufferOperation(fileUrl: url)
        op.completionBlock = {
            self.state = .ready
            
            switch op.result {
            case .success(let pcmBuffer):
                self.amps = AudioService.compress(buffer: pcmBuffer)
                self.pcmBuffer = pcmBuffer
                self.visibleTimeRange = 0.0 ..< pcmBuffer.duration
                
            case .failure(let error):
                
                self.error = error
                
            case .none:
                break
            }
        }
        serviceQueue.addOperation(op)
    }
}
