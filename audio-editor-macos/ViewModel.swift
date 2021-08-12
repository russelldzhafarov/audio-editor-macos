//
//  ViewModel.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Combine
import AVFoundation
import Accelerate

class ViewModel: ObservableObject {
    
    enum PlayerState {
        case playing, stopped, paused
    }
    
    struct ReadAudioError: Error {
    }
    
    struct AudioData {
        let fileFormat: String
        let duration: TimeInterval
        let channelCount: Int
        let pcmBuffer: AVAudioPCMBuffer
        let sampleData: AudioSampleData
        let compressedData: AudioSampleData
    }
    
    struct AudioSampleData {
        let sampleRate: Double
        let lamps: [Float]
        let ramps: [Float]
    }
    
    @Published var selectedTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published var currentTime: TimeInterval = 0.0
    
    @Published var highlighted = false
    
    @Published var loaded = false
    
    var duration = TimeInterval(0)
    var sampleRate = Double(0)
    var amplitudes = [Float]()
    var channelCount = AVAudioChannelCount(0)
    
    func seek(to time: TimeInterval) {
        currentTime = time
    }
    
    func play() {
        player.play()
    }
    func pause() {
        player.pause()
    }
    func stop() {
        player.stop()
    }
    
    public func power(at time: TimeInterval) -> Float {
        guard let sampleData = audioData?.compressedData else { return 0.0 }
        
        let index = Int(time * sampleData.sampleRate)
        
        guard sampleData.lamps.indices.contains(index) else { return 0.0 }
        
        let power = sampleData.lamps[index]
        
        let avgPower = 20 * log2(power)
        
        return scaledPower(power: avgPower)
    }
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return 0.0
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return 0.0
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
    
    func openAudioFile(at url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: file.fileFormat.sampleRate,
                                             channels: file.fileFormat.channelCount,
                                             interleaved: false)
            else {
                throw ReadAudioError()
            }
            
            let asset = AVAsset(url: url)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(file.length)) else {
                throw ReadAudioError()
            }
            
            try file.read(into: buffer)
            
            let leftAmps = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[0], count:Int(buffer.frameLength)))
            let rightAmps = Array(UnsafeBufferPointer(start: buffer.floatChannelData?[1], count:Int(buffer.frameLength)))
            
            let compressedAmps = compress(leftAmps, compression: 500)
            let compressedSampleRate = Double(compressedAmps.count) / asset.duration.seconds
            
            audioData = AudioData(fileFormat: url.pathExtension,
                                  duration: asset.duration.seconds,
                                  channelCount: Int(file.fileFormat.channelCount),
                                  pcmBuffer: buffer,
                                  sampleData: AudioSampleData(sampleRate: file.fileFormat.sampleRate,
                                                              lamps: leftAmps,
                                                              ramps: rightAmps),
                                  compressedData: AudioSampleData(sampleRate: compressedSampleRate,
                                                                  lamps: compressedAmps,
                                                                  ramps: []))
            
            visibleTimeRange = 0.0 ..< asset.duration.seconds
            loaded = true
            
        } catch {
            
        }
    }
    
    var compressed = [Float]()
    var compressedSampleRate = Double(0)
    
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
