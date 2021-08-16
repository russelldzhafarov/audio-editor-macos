//
//  ReadAudioOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 15.08.2021.
//

import AVFoundation
import Accelerate

class ReadAudioOperation: ResultOperation<AudioFile> {
    
    let fileUrl: URL
    
    init(fileUrl: URL) {
        self.fileUrl = fileUrl
        super.init()
    }
    
    override func main() {
        let time = CACurrentMediaTime()
        
        do {
            let file = try AVAudioFile(forReading: fileUrl)
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: file.fileFormat.sampleRate,
                                             channels: file.fileFormat.channelCount,
                                             interleaved: false)
            else {
                throw AudioBufferError()
            }
            
            let asset = AVAsset(url: fileUrl)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(file.length)) else {
                throw AudioBufferError()
            }
            
            try file.read(into: buffer)
            
            var amps = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
            
            amps = compress(amps, compression: Int(asset.duration.seconds * 10))
            let compressedSampleRate = Double(amps.count) / asset.duration.seconds
            
            result = .success(
                AudioFile(fileFormat: fileUrl.pathExtension,
                          duration: asset.duration.seconds,
                          sampleRate: file.fileFormat.sampleRate,
                          channelCount: Int(file.fileFormat.channelCount),
                          pcmBuffer: buffer,
                          compressedData: AudioSampleData(sampleRate: compressedSampleRate,
                                                          amps: amps))
            )
            
        } catch {
            result = .failure(error)
        }
        
        print("ReadAudioOperation took: \(CACurrentMediaTime() - time) sec")
    }
    
    func compress(_ inputSignal: [Float], compression: Int) -> [Float] {
        let time = CACurrentMediaTime()
        
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
        
        print("CompressOperation took: \(CACurrentMediaTime() - time) sec")
        
        return downSampledData
    }
}
