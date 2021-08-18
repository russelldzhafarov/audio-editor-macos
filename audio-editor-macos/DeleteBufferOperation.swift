//
//  DeleteBufferOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class DeleteBufferOperation: ResultOperation<(AVAudioPCMBuffer, AVAudioPCMBuffer)> {
    
    let pcmBuffer: AVAudioPCMBuffer
    let startTime: TimeInterval
    let endTime: TimeInterval
    
    init(pcmBuffer: AVAudioPCMBuffer, startTime: TimeInterval, endTime: TimeInterval) {
        self.pcmBuffer = pcmBuffer
        self.startTime = startTime
        self.endTime = endTime
        super.init()
    }
    
    override func main() {
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if startTime > 0.0 {
            let from1 = AVAudioFramePosition(1)
            let to1 = AVAudioFramePosition(startTime * pcmBuffer.sampleRate)
            
            guard let segment1 = pcmBuffer.segment(from: from1, to: to1) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment1)
        }
        
        // Copy second part
        if endTime < pcmBuffer.duration {
            let from2 = AVAudioFramePosition(endTime * pcmBuffer.sampleRate)
            let to2 = AVAudioFramePosition(pcmBuffer.frameLength)
            
            guard let segment2 = pcmBuffer.segment(from: from2, to: to2) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment2)
        }
        
        // Concatenate
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        guard let resBuffer = AVAudioPCMBuffer(pcmFormat: pcmBuffer.format, frameCapacity: frameCapacity) else {
            result = .failure(AudioBufferError())
            return
        }
        
        buffers.forEach { resBuffer.append($0) }
        
        // Copy removed part
        let from = AVAudioFramePosition(max(1,
                                            startTime * pcmBuffer.sampleRate))
        let to = AVAudioFramePosition(min(Double(pcmBuffer.frameLength),
                                          endTime * pcmBuffer.sampleRate))
        
        guard let removed = pcmBuffer.segment(from: from, to: to) else {
            result = .failure(AudioBufferError())
            return
        }
        
        result = .success((resBuffer, removed))
    }
}
