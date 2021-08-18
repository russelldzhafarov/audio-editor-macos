//
//  ScheduleBufferOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

struct AudioBufferError: LocalizedError {
    var errorDescription: String? {
        return "Can't read the audio file, please try again later."
    }
}

class ScheduleBufferOperation: ResultOperation<Void> {
    
    let audioFile: AudioFile
    let audioPlayer: AVAudioPlayerNode
    let startTime: TimeInterval
    let timeRange: Range<TimeInterval>?
    let completionHandler: AVAudioNodeCompletionHandler?
    
    init(audioFile: AudioFile, audioPlayer: AVAudioPlayerNode, startTime: TimeInterval, timeRange: Range<TimeInterval>?, completionHandler: AVAudioNodeCompletionHandler?) {
        self.audioFile = audioFile
        self.audioPlayer = audioPlayer
        self.startTime = startTime
        self.timeRange = timeRange
        self.completionHandler = completionHandler
        super.init()
    }
    
    override func main() {
        let time = CACurrentMediaTime()
        
        if let timeRange = timeRange {
            guard let segment = AudioService.copy(buffer: audioFile.pcmBuffer, timeRange: timeRange) else {
                result = .failure(AudioBufferError())
                return
            }
            
            audioPlayer.scheduleBuffer(segment, completionHandler: completionHandler)
            
        } else {
            if startTime == 0 {
                audioPlayer.scheduleBuffer(audioFile.pcmBuffer, completionHandler: completionHandler)
                
            } else {
                guard startTime < audioFile.duration, let segment = AudioService.copy(buffer: audioFile.pcmBuffer, timeRange: startTime..<audioFile.duration) else {
                    result = .failure(AudioBufferError())
                    return
                }
                
                audioPlayer.scheduleBuffer(segment, completionHandler: completionHandler)
            }
        }
        
        print("ScheduleBufferOperation took: \(CACurrentMediaTime() - time) sec")
        
        result = .success(Void())
    }
}
