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
    enum State {
        case empty, processing, ready
    }
    enum EditError: Error {
        case delete, copy, paste
    }
    
    @Published var selectedTimeRange: Range<TimeInterval>?
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var highlighted = false
    @Published var state: State = .empty
    
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
                timer?.fire()
                
            case .paused, .stopped:
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    var undoManager: UndoManager?
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    var status: String? {
        guard let pcmBuffer = pcmBuffer else { return nil }
        return "\(pcmBuffer.sampleRate / Double(1000)) kHz  |  \(pcmBuffer.channelCount == 1 ? "Mono" : "Stereo")  |  \(pcmBuffer.duration.mmss())"
    }
    
    // MARK: - Undo / Redo Operations
    func delete(start: TimeInterval, end: TimeInterval) {
        guard let edited = pcmBuffer?.remove(startTime: start, endTime: end),
              let removed = pcmBuffer?.copy(timeRange: start..<end) else {
            self.error = EditError.delete
            return
        }
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.paste(buffer: removed, at: start)
        }
        undoManager?.setActionName("Delete")
        
        pcmBuffer = edited
        amps = edited.compressed()
        state = .ready
        selectedTimeRange = nil
        visibleTimeRange = visibleTimeRange.clamped(to: 0..<edited.duration)
    }
    
    func paste(buffer: AVAudioPCMBuffer, at time: TimeInterval) {
        guard let edited = pcmBuffer?.paste(buffer: buffer, at: time) else {
            self.error = EditError.paste
            return
        }
        
        undoManager?.registerUndo(withTarget: self) { target in
            target.delete(start: time, end: time + buffer.duration)
        }
        undoManager?.setActionName("Paste")
        
        pcmBuffer = edited
        amps = edited.compressed()
        state = .ready
        selectedTimeRange = time ..< (time + Double(buffer.frameLength) / buffer.sampleRate)
    }
    
    func copy() {
        guard let selectedTimeRange = selectedTimeRange,
              let pcmBuffer = pcmBuffer else { return }
        
        state = .processing
        serviceQueue.addOperation {
            defer {
                self.state = .ready
            }
            guard let buffer = pcmBuffer.copy(timeRange: selectedTimeRange) else {
                self.error = EditError.copy
                return
            }
            
            do {
                let obj = AudioData(format: buffer.format, data: NSData(buffer: buffer))
                
                let codedData = try NSKeyedArchiver.archivedData(withRootObject: obj, requiringSecureCoding: true)
                
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.declareTypes([.audio], owner: nil)
                pb.setData(codedData, forType: .audio)
                
            } catch {
                self.error = error
            }
        }
    }
    
    func paste() {
        let pb = NSPasteboard.general
        
        guard let type = pb.availableType(from: [.audio]),
              type == .audio,
              let data = pb.data(forType: .audio) else { return }
        
        do {
            guard let obj = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? AudioData else {
                throw EditError.paste
            }
            
            guard let buffer = AVAudioPCMBuffer(data: obj.data as Data, format: obj.format) else {
                throw EditError.paste
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
    
    func play(buffer: AVAudioPCMBuffer) {
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer,
                            to: audioEngine.outputNode,
                            format: nil)
        
        let completionHandler: AVAudioNodeCompletionHandler = { [weak self] in
            self?.playerState = .stopped
        }
        
        if let selectedTimeRange = selectedTimeRange {
            guard let segment = buffer.copy(timeRange: selectedTimeRange) else {
                self.error = EditError.copy
                return
            }
            
            audioPlayer.scheduleBuffer(segment, completionHandler: completionHandler)
            
        } else {
            if currentTime == .zero {
                audioPlayer.scheduleBuffer(buffer, completionHandler: completionHandler)
                
            } else {
                guard currentTime < buffer.duration,
                      let segment = buffer.copy(timeRange: currentTime..<buffer.duration)
                else {
                    self.error = EditError.copy
                    return
                }
                
                audioPlayer.scheduleBuffer(segment, completionHandler: completionHandler)
            }
        }
        
        do {
            try audioEngine.start()
            audioPlayer.play()
            
            playerState = .playing
            
        } catch {
            self.error = error
        }
    }
    
    func readAudioFile(at url: URL) {
        state = .processing
        serviceQueue.addOperation {
            defer {
                self.state = .ready
            }
            do {
                self.pcmBuffer = try AVAudioPCMBuffer(url: url)
                self.amps = self.pcmBuffer!.compressed()
                self.visibleTimeRange = 0.0 ..< self.pcmBuffer!.duration
                
            } catch {
                self.error = error
            }
        }
    }
}
