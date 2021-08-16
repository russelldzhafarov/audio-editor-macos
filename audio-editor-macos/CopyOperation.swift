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
        let from = AVAudioFramePosition(timeRange.lowerBound * audioFile.sampleRate)
        let to = AVAudioFramePosition(timeRange.upperBound * audioFile.sampleRate)
        
        guard let segment = audioFile.pcmBuffer.segment(from: from, to: to) else {
            result = .failure(AudioBufferError())
            return
        }
        
        let data = Data(buffer: segment)
        
        result = .success(data)
    }
}
