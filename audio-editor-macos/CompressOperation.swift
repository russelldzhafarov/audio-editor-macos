//
//  CompressOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation
import Accelerate

class CompressOperation: ResultOperation<[Float]> {
    
    let buffer: AVAudioPCMBuffer
    
    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
        super.init()
    }
    
    override func main() {
        let time = CACurrentMediaTime()
        
        let input = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
        let compression = Int(buffer.frameCapacity) / 1000
        
        var processingBuffer = [Float](repeating: 0.0,
                                       count: Int(input.count))
        
        // Take the absolute values to get amplitude
        vDSP_vabs(input,                            // Single-precision real input vector.
                  1,                                // Stride size for A.
                  &processingBuffer,                // Single-precision real output vector.
                  1,                                // Address stride for C.
                  vDSP_Length(input.count))         // The number of elements to process.
        
        let filter = [Float](repeating: 1.0 / Float(compression),
                             count: compression)
        
        let downSampledLength = input.count / compression
        
        var downSampledData = [Float](repeating: 0.0,
                                      count: downSampledLength)
        
        vDSP_desamp(processingBuffer,               // Input signal.
                    vDSP_Stride(compression),       // Decimation Factor.
                    filter,                         // Filter.
                    &downSampledData,               // Output.
                    vDSP_Length(downSampledLength), // Output length.
                    vDSP_Length(compression))       // Filter length.
        
        result = .success(downSampledData)
        
        print("CompressOperation took: \(CACurrentMediaTime() - time) sec")
    }
}
