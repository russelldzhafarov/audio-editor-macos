//
//  PasteOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation
import Accelerate

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
        // Copy first part
        let from1 = AVAudioFramePosition(1)
        let to1 = AVAudioFramePosition(time * audioFile.sampleRate)
        
        guard let segment1 = audioFile.pcmBuffer.segment(from: from1, to: to1) else {
            result = .failure(AudioBufferError())
            return
        }
        
        // Copy second part
        let from2 = AVAudioFramePosition(time * audioFile.sampleRate)
        let to2 = AVAudioFramePosition(audioFile.duration * audioFile.sampleRate)
        
        guard let segment2 = audioFile.pcmBuffer.segment(from: from2, to: to2) else {
            result = .failure(AudioBufferError())
            return
        }
        
        // Convert data to buffer
        guard let pbBuffer = AVAudioPCMBuffer(data: data, format: audioFile.pcmBuffer.format) else {
            result = .failure(AudioBufferError())
            return
        }
        
        // Concatenate
        let frameCapacity = segment1.frameCapacity + pbBuffer.frameCapacity + segment2.frameCapacity
        guard let resultBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.pcmBuffer.format, frameCapacity: frameCapacity) else {
            result = .failure(AudioBufferError())
            return
        }
        
        resultBuffer.append(segment1)
        resultBuffer.append(pbBuffer)
        resultBuffer.append(segment2)
        
        let duration = Double(resultBuffer.frameLength) / audioFile.sampleRate
        
        var amps = Array(UnsafeBufferPointer(start: resultBuffer.floatChannelData?[0], count:Int(resultBuffer.frameLength)))
        
        amps = compress(amps, compression: Int(duration * 10))
        let compressedSampleRate = Double(amps.count) / duration
        
        let resultFile = AudioFile(fileFormat: audioFile.fileFormat,
                                   duration: duration,
                                   sampleRate: audioFile.sampleRate,
                                   channelCount: audioFile.channelCount,
                                   pcmBuffer: resultBuffer,
                                   compressedData: AudioSampleData(sampleRate: compressedSampleRate,
                                                                   amps: amps))
        
        result = .success((resultFile,
                           time ..< Double(pbBuffer.frameCapacity) * pbBuffer.format.sampleRate))
    }
    
    func compress(_ inputSignal: [Float], compression: Int) -> [Float] {
        
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
