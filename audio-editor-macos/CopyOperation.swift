//
//  CopyOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

class CopyOperation: ResultOperation<Data> {
    
    let audioFile: AudioFile
    let timeRange: Range<TimeInterval>
    
    init(audioFile: AudioFile, timeRange: Range<TimeInterval>) {
        self.audioFile = audioFile
        self.timeRange = timeRange
        super.init()
    }
    
    override func main() {
        guard let segment = AudioService.copy(buffer: audioFile.pcmBuffer, timeRange: timeRange) else {
            result = .failure(AudioBufferError())
            return
        }
        
        let data = Data(buffer: segment)
        
        result = .success(data)
    }
}
