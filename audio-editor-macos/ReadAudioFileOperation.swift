//
//  ReadAudioFileOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 15.08.2021.
//

import AVFoundation
import Accelerate

extension ReadAudioFileOperation.ReadAudioFileError: LocalizedError {
    var errorDescription: String? {
        return "Can't read the audio file, please try again later."
    }
}

class ReadAudioFileOperation: Operation {
    struct ReadAudioFileError: Error {
    }
    
    var result: Result<AudioFile, Error>?
    
    let fileUrl: URL
    
    init(fileUrl: URL) {
        self.fileUrl = fileUrl
        super.init()
    }
    
    override func main() {
        let startTime = CACurrentMediaTime()
        
        do {
            let file = try AVAudioFile(forReading: fileUrl)
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: file.fileFormat.sampleRate,
                                             channels: file.fileFormat.channelCount,
                                             interleaved: false)
            else {
                throw ReadAudioFileError()
            }
            
            let asset = AVAsset(url: fileUrl)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(file.length)) else {
                throw ReadAudioFileError()
            }
            
            try file.read(into: buffer)
            
            let leftAmps = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
            let rightAmps = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[1], count:Int(buffer.frameLength)))
            
            let compression = asset.duration.seconds.rounded()
            let compressedAmps = compress(leftAmps, compression: Int(compression))
            let compressedSampleRate = Double(compressedAmps.count) / asset.duration.seconds
            
            result = .success(
                AudioFile(fileFormat: fileUrl.pathExtension,
                          duration: asset.duration.seconds,
                          channelCount: Int(file.fileFormat.channelCount),
                          pcmBuffer: buffer,
                          sampleData: AudioSampleData(sampleRate: file.fileFormat.sampleRate,
                                                      lamps: leftAmps,
                                                      ramps: rightAmps),
                          compressedData: AudioSampleData(sampleRate: compressedSampleRate,
                                                          lamps: compressedAmps,
                                                          ramps: []))
            )
            
        } catch {
            result = .failure(error)
        }
        
        print("Read audio file took: \(CACurrentMediaTime() - startTime) sec")
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
