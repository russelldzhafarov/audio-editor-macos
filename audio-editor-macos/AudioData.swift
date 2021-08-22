//
//  AudioData.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import AVFoundation

class AudioData: NSObject, NSCoding, NSSecureCoding {
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    enum Key: String {
        case format
        case data
    }
    
    let format: AVAudioFormat
    let data: NSData
    
    init(format: AVAudioFormat, data: NSData) {
        self.format = format
        self.data = data
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(format, forKey: Key.format.rawValue)
        coder.encode(data, forKey: Key.data.rawValue)
    }
    
    required convenience init?(coder: NSCoder) {
        guard
            let format = coder.decodeObject(of: AVAudioFormat.self, forKey: Key.format.rawValue),
            let data = coder.decodeObject(of: NSData.self, forKey: Key.data.rawValue)
        else {
            return nil
        }
        self.init(format: format, data: data)
    }
}
