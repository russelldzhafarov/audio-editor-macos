//
//  ReadAudioOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 15.08.2021.
//

import AVFoundation

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
            
            let downsampled = AudioService.compress(buffer: buffer)
            
            result = .success(
                AudioFile(fileFormat: fileUrl.pathExtension,
                          duration: asset.duration.seconds,
                          sampleRate: file.fileFormat.sampleRate,
                          channelCount: Int(file.fileFormat.channelCount),
                          pcmBuffer: buffer,
                          compressedData: AudioSampleData(sampleRate: downsampled.sampleRate,
                                                          amps: downsampled.data))
            )
            
        } catch {
            result = .failure(error)
        }
        
        print("ReadAudioOperation took: \(CACurrentMediaTime() - time) sec")
    }
}
