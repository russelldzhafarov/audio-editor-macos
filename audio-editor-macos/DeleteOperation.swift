//
//  DeleteOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class DeleteOperation: ResultOperation<AudioFile> {
    
    let audioFile: AudioFile
    let timeRange: Range<TimeInterval>
    
    init(audioFile: AudioFile, timeRange: Range<TimeInterval>) {
        self.audioFile = audioFile
        self.timeRange = timeRange
        super.init()
    }
    
    override func main() {
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if timeRange.lowerBound > 0.0 {
            let from1 = AVAudioFramePosition(1)
            let to1 = AVAudioFramePosition(timeRange.lowerBound * audioFile.sampleRate)
            
            guard let segment1 = audioFile.pcmBuffer.segment(from: from1, to: to1) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment1)
        }
        
        // Copy second part
        if timeRange.upperBound < audioFile.duration {
            let from2 = AVAudioFramePosition(timeRange.upperBound * audioFile.sampleRate)
            let to2 = AVAudioFramePosition(audioFile.pcmBuffer.frameLength)
            
            guard let segment2 = audioFile.pcmBuffer.segment(from: from2, to: to2) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment2)
        }
        
        // Concatenate
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.pcmBuffer.format, frameCapacity: frameCapacity) else {
            result = .failure(AudioBufferError())
            return
        }
        
        buffers.forEach { buffer.append($0) }
        
        let duration = Double(buffer.frameLength) / audioFile.sampleRate
        
        let downsampled = AudioService.compress(buffer: buffer)
        
        let resultFile = AudioFile(fileFormat: audioFile.fileFormat,
                                   duration: duration,
                                   sampleRate: audioFile.sampleRate,
                                   channelCount: audioFile.channelCount,
                                   pcmBuffer: buffer,
                                   compressedData: AudioSampleData(sampleRate: downsampled.sampleRate,
                                                                   amps: downsampled.data))
        
        result = .success(resultFile)
    }
}
