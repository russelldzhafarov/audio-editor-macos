//
//  CombineBuffersOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class CombineBuffersOperation: ResultOperation<AVAudioPCMBuffer> {
    
    let buffers: [AVAudioPCMBuffer]
    
    init(buffers: [AVAudioPCMBuffer]) {
        self.buffers = buffers
        super.init()
    }
    
    override func main() {
        precondition(buffers.count > 0)
        
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        if let buffer = AVAudioPCMBuffer(pcmFormat: buffers[0].format, frameCapacity: frameCapacity) {
            buffers.forEach { buffer.append($0) }
            result = .success(buffer)
            
        } else {
            result = .failure(AudioBufferError())
        }
    }
}
