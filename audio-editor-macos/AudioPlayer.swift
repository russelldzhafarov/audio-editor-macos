//
//  AudioPlayer.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import AVFoundation
import Combine

class AudioPlayer: ObservableObject {
    
    enum State {
        case playing, stopped
    }
    
    @Published var state: State = .stopped
    @Published var currentTime = TimeInterval(0)
    
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
    
    private func setupPlayer(buffer: AVAudioPCMBuffer) {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
        engine.prepare()
    }
    
    private func startEngine() throws {
        try engine.start()
    }
    
    func play(buffer: AVAudioPCMBuffer) throws {
        if !engine.isRunning {
            setupPlayer(buffer: buffer)
            try startEngine()
            playerNode.play()
        }
        
        playerNode.scheduleBuffer(buffer, completionHandler: { [weak self] in self?.stop() })
        
        state = .playing
        
        let seekTime = currentTime
        let sampleRate = buffer.sampleRate
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(0.025), repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            
            strongSelf.currentTime = (seekTime + Double(strongSelf.currentFrame)) / sampleRate
        }
        timer?.fire()
    }
    
    func stop() {
        playerNode.stop()
        engine.stop()
        timer?.invalidate()
        timer = nil
        state = .stopped
    }
}
