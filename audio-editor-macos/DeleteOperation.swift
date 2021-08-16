//
//  DeleteOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation
import Accelerate

class DeleteOperation: ResultOperation<AudioFile> {
    
    let audioFile: AudioFile
    let timeRange: Range<TimeInterval>
    
    init(audioFile: AudioFile, timeRange: Range<TimeInterval>) {
        self.audioFile = audioFile
        self.timeRange = timeRange
        super.init()
    }
    
    override func main() {
        // Copy first part
        let from1 = AVAudioFramePosition(1)
        let to1 = AVAudioFramePosition(timeRange.lowerBound * audioFile.sampleRate)
        
        guard let segment1 = audioFile.pcmBuffer.segment(from: from1, to: to1) else {
            result = .failure(AudioBufferError())
            return
        }
        
        // Copy second part
        let from2 = AVAudioFramePosition(timeRange.upperBound * audioFile.sampleRate)
        let to2 = AVAudioFramePosition(audioFile.duration * audioFile.sampleRate)
        
        guard let segment2 = audioFile.pcmBuffer.segment(from: from2, to: to2) else {
            result = .failure(AudioBufferError())
            return
        }
        
        // Concatenate
        let frameCapacity = segment1.frameCapacity + segment2.frameCapacity
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.pcmBuffer.format, frameCapacity: frameCapacity) else {
            result = .failure(AudioBufferError())
            return
        }
        
        buffer.append(segment1)
        buffer.append(segment2)
        
        let duration = Double(buffer.frameLength) / audioFile.sampleRate
        
        var amps = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
        
        amps = compress(amps, compression: Int(duration * 10))
        let compressedSampleRate = Double(amps.count) / duration
        
        let resultFile = AudioFile(fileFormat: audioFile.fileFormat,
                                   duration: duration,
                                   sampleRate: audioFile.sampleRate,
                                   channelCount: audioFile.channelCount,
                                   pcmBuffer: buffer,
                                   compressedData: AudioSampleData(sampleRate: compressedSampleRate,
                                                                   amps: amps))
        
        result = .success(resultFile)
    }
    
    func compress(_ inputSignal: [Float], compression: Int) -> [Float] {
        guard compression > 0 else { return [] }
        
        var processingBuffer = [Float](repeating: 0.0,
                                       count: Int(inputSignal.count))
        
        // Take the absolute values to get amplitude
        vDSP_vabs(inputSignal,                      // Single-precision real input vector.
                  1,                                // Stride size for A.
                  &processingBuffer,                // Single-precision real output vector.
                  1,                                // Address stride for C.
                  vDSP_Length(inputSignal.count))   // The number of elements to process.
        
        let filter = [Float](repeating: 1.0 / Float(compression),
                             count: Int(compression))
        
        let downSampledLength = inputSignal.count / compression
        
        var downSampledData = [Float](repeating: 0.0,
                                      count: downSampledLength)
        
        vDSP_desamp(processingBuffer,               // Input signal.
                    vDSP_Stride(compression),       // Decimation Factor.
                    filter,                         // Filter.
                    &downSampledData,               // Output.
                    vDSP_Length(downSampledLength), // Output length.
                    vDSP_Length(compression))       // Filter length.
        
        return downSampledData
    }
}
