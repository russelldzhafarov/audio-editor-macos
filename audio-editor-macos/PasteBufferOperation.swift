//
//  PasteBufferOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class PasteBufferOperation: ResultOperation<AVAudioPCMBuffer> {
    
    struct BufferFormatError: LocalizedError {
        var errorDescription: String? {
            return "Format mismatch"
        }
    }
    
    let srcBuffer: AVAudioPCMBuffer
    let dstBuffer: AVAudioPCMBuffer
    let time: TimeInterval
    
    init(srcBuffer: AVAudioPCMBuffer, to dstBuffer: AVAudioPCMBuffer, at time: TimeInterval) {
        self.srcBuffer = srcBuffer
        self.dstBuffer = dstBuffer
        self.time = time
        super.init()
    }
    
    override func main() {
        guard srcBuffer.format == dstBuffer.format else {
            result = .failure(BufferFormatError())
            return
        }
        
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if time > 0.0 {
            guard let segment1 = dstBuffer.copy(timeRange: 0.0..<time) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment1)
        }
        
        buffers.append(srcBuffer)
        
        // Copy second part
        if time < dstBuffer.duration {
            guard let segment2 = dstBuffer.copy(timeRange: time..<dstBuffer.duration) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment2)
        }
        
        // Concatenate
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        guard let resBuffer = AVAudioPCMBuffer(pcmFormat: dstBuffer.format, frameCapacity: frameCapacity) else {
            result = .failure(AudioBufferError())
            return
        }
        
        buffers.forEach { resBuffer.append($0) }
        
        result = .success(resBuffer)
    }
}
