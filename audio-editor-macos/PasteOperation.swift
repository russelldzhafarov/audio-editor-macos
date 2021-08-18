//
//  PasteOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class PasteOperation: ResultOperation<(AudioFile, Range<TimeInterval>)> {
    
    let data: Data
    let audioFile: AudioFile
    let time: TimeInterval
    
    init(data: Data, to audioFile: AudioFile, at time: TimeInterval) {
        self.data = data
        self.audioFile = audioFile
        self.time = time
        super.init()
    }
    
    override func main() {
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if time > 0.0 {
            guard let segment1 = AudioService.copy(buffer: audioFile.pcmBuffer, timeRange: 0.0..<time) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment1)
        }
        
        // Convert data to buffer
        guard let pbBuffer = AVAudioPCMBuffer(data: data, format: audioFile.pcmBuffer.format) else {
            result = .failure(AudioBufferError())
            return
        }
        
        buffers.append(pbBuffer)
        
        // Copy second part
        if time < audioFile.duration {
            guard let segment2 = AudioService.copy(buffer: audioFile.pcmBuffer, timeRange: time..<audioFile.duration) else {
                result = .failure(AudioBufferError())
                return
            }
            
            buffers.append(segment2)
        }
        
        // Concatenate
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        guard let resultBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.pcmBuffer.format, frameCapacity: frameCapacity) else {
            result = .failure(AudioBufferError())
            return
        }
        
        buffers.forEach { resultBuffer.append($0) }
        
        let duration = Double(resultBuffer.frameLength) / audioFile.sampleRate
        
        let downsampled = AudioService.compress(buffer: resultBuffer)
        
        let resultFile = AudioFile(fileFormat: audioFile.fileFormat,
                                   duration: duration,
                                   sampleRate: audioFile.sampleRate,
                                   channelCount: audioFile.channelCount,
                                   pcmBuffer: resultBuffer,
                                   compressedData: AudioSampleData(sampleRate: downsampled.sampleRate,
                                                                   amps: downsampled.data))
        
        result = .success((resultFile,
                           time ..< (time + Double(pbBuffer.frameCapacity) / pbBuffer.format.sampleRate)))
    }
}
