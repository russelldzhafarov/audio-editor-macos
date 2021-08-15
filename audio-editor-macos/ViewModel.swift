//
//  ViewModel.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Combine
import AVFoundation
import Accelerate

extension AVAudioPCMBuffer {
    func segment(from startFrame: AVAudioFramePosition, to endFrame: AVAudioFramePosition) -> AVAudioPCMBuffer? {
        guard endFrame > startFrame else { return nil }
        
        let framesToCopy = AVAudioFrameCount(endFrame - startFrame)
        guard let segment = AVAudioPCMBuffer(pcmFormat: self.format, frameCapacity: framesToCopy) else { return nil }
        
        let sampleSize = self.format.streamDescription.pointee.mBytesPerFrame
        
        let srcPtr = UnsafeMutableAudioBufferListPointer(self.mutableAudioBufferList)
        let dstPtr = UnsafeMutableAudioBufferListPointer(segment.mutableAudioBufferList)
        for (src, dst) in zip(srcPtr, dstPtr) {
            memcpy(dst.mData, src.mData?.advanced(by: Int(startFrame) * Int(sampleSize)), Int(framesToCopy) * Int(sampleSize))
        }
        
        segment.frameLength = framesToCopy
        return segment
    }
}

extension ViewModel.ReadAudioError: LocalizedError {
    var errorDescription: String? {
        return "Can't read the audio file, please try again later."
    }
}

class ViewModel: ObservableObject {
    enum PlayerState {
        case playing, stopped, paused
    }
    struct ReadAudioError: Error {
    }
    
    @Published var selectedTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var highlighted = false
    @Published var loaded = false
    var looped = true
    
    var duration: TimeInterval {
        audioFile?.duration ?? TimeInterval(0)
    }
    
    var visibleDur: TimeInterval {
        visibleTimeRange.upperBound - visibleTimeRange.lowerBound
    }
    
    var audioFile: AudioFile?
    
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
                          let audioFile = strongSelf.audioFile else { return }
                    
                    strongSelf.currentTime = seekTime + (Double(strongSelf.currentFrame) / audioFile.sampleData.sampleRate)
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
        guard let audioFile = audioFile else { return nil }
        return "\(audioFile.fileFormat)  |  \(audioFile.sampleData.sampleRate / Double(1000)) kHz  |  \(audioFile.channelCount == 1 ? "Mono" : "Stereo")  |  \(audioFile.duration.mmss())"
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
            do {
                guard let audioFile = audioFile else {
                    throw ReadAudioError()
                }
                
                audioEngine.attach(audioPlayer)
                audioEngine.connect(audioPlayer,
                                    to: audioEngine.outputNode,
                                    format: nil)
                
                if selectedTimeRange.isEmpty {
                    if currentTime == 0 {
                        audioPlayer.scheduleBuffer(audioFile.pcmBuffer) { [weak self] in
                            self?.playerState = .stopped
                        }
                    } else {
                        let from = AVAudioFramePosition(currentTime * audioFile.sampleData.sampleRate)
                        let to = AVAudioFramePosition(duration * audioFile.sampleData.sampleRate)
                        
                        guard let segment = audioFile.pcmBuffer.segment(from: from, to: to) else {
                            throw ReadAudioError()
                        }
                        
                        audioPlayer.scheduleBuffer(segment) { [weak self] in
                            self?.playerState = .stopped
                        }
                    }
                    
                } else {
                    
                    let from = AVAudioFramePosition(selectedTimeRange.lowerBound * audioFile.sampleData.sampleRate)
                    let to = AVAudioFramePosition(selectedTimeRange.upperBound * audioFile.sampleData.sampleRate)
                    
                    guard let segment = audioFile.pcmBuffer.segment(from: from, to: to) else {
                        throw ReadAudioError()
                    }
                    
                    audioPlayer.scheduleBuffer(segment) { [weak self] in
                        self?.playerState = .stopped
                    }
                }
                
                try audioEngine.start()
                audioPlayer.play()
                
                playerState = .playing
                
            } catch {
                self.error = error
            }
        }
    }
    func stop() {
        audioPlayer.stop()
        audioEngine.stop()
        playerState = .stopped
    }
    func forward() {
        selectedTimeRange = 0.0 ..< 0.0
        seek(to: currentTime + TimeInterval(15))
    }
    func forwardEnd() {
        selectedTimeRange = 0.0 ..< 0.0
        seek(to: duration)
    }
    func backward() {
        selectedTimeRange = 0.0 ..< 0.0
        seek(to: currentTime - TimeInterval(15))
    }
    func backwardEnd() {
        selectedTimeRange = 0.0 ..< 0.0
        seek(to: TimeInterval(0))
    }
    
    public func power(at time: TimeInterval) -> Float {
        guard let sampleData = audioFile?.compressedData else { return 0.0 }
        
        let index = Int(time * sampleData.sampleRate)
        
        guard sampleData.lamps.indices.contains(index) else { return 0.0 }
        
        let power = sampleData.lamps[index]
        
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
        let op = ReadAudioFileOperation(fileUrl: url)
        op.completionBlock = {
            switch op.result {
            case .success(let audioFile):
                self.audioFile = audioFile
                self.visibleTimeRange = 0.0 ..< audioFile.duration
                self.loaded = true
                
            case .failure(let error):
                self.error = error
                
            case .none:
                break
            }
        }
        serviceQueue.addOperation(op)
    }
}
