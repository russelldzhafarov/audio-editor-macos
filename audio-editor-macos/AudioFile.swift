//
//  AudioData.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 15.08.2021.
//

import AVFoundation

struct AudioFile {
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
