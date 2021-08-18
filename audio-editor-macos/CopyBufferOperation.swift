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
        if let segment = AudioService.copy(buffer: buffer, timeRange: startTime..<endTime) {
            result = .success(segment)
        } else {
            result = .failure(AudioBufferError())
        }
    }
}
