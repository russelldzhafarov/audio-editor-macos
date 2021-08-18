//
//  AudioData.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 15.08.2021.
//

import AVFoundation

class AudioSampleData {
    let sampleRate: Double
    let amps: [Float]
    
    init(sampleRate: Double, amps: [Float]) {
        self.sampleRate = sampleRate
        self.amps = amps
    }
}
