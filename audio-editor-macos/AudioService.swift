//
//  AudioService.swift
//  audio-editor-macos
//
//  Created by blessed on 17.08.2021.
//

import AVFoundation
import Accelerate

class AudioService {
    static func compress(buffer: AVAudioPCMBuffer) -> (data: [Float], sampleRate: Double) {
        
        let inputSignal = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
        
        let duration = Double(buffer.frameLength) / buffer.format.sampleRate
        let compression = max(1, Int(duration / Double(10)))
        
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
        
        let sampleRate = Double(downSampledData.count) / duration
        
        return (data: downSampledData, sampleRate: sampleRate)
    }
    
    static func copy(buffer: AVAudioPCMBuffer, timeRange: Range<TimeInterval>) -> AVAudioPCMBuffer? {
        guard timeRange.upperBound > timeRange.lowerBound else { return nil }
        
        let from = AVAudioFramePosition(max(1,
                                            timeRange.lowerBound * buffer.format.sampleRate))
        
        let to = AVAudioFramePosition(min(Double(buffer.frameLength),
                                          timeRange.upperBound * buffer.format.sampleRate))
        
        return buffer.segment(from: from, to: to)
    }
}
