//
//  CopyBufferOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class CopyBufferOperation: ResultOperation<AVAudioPCMBuffer> {
    
    let buffer: AVAudioPCMBuffer
    let startTime: TimeInterval
    let endTime: TimeInterval
    
    init(buffer: AVAudioPCMBuffer, startTime: TimeInterval, endTime: TimeInterval) {
        self.buffer = buffer
        self.startTime = startTime
        self.endTime = endTime
        super.init()
    }
    
    override func main() {
        let from = AVAudioFramePosition(startTime * buffer.format.sampleRate)
        let to = AVAudioFramePosition(endTime * buffer.format.sampleRate)
        
        if let segment = buffer.segment(from: from, to: to) {
            result = .success(segment)
        } else {
            result = .failure(AudioBufferError())
        }
    }
}
