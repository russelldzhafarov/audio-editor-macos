//
//  AudioPasteboardData.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 21.08.2021.
//

import AVFoundation
import AppKit

class AudioPasteboardData: NSObject, NSCoding, NSSecureCoding {
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    enum Keys: String {
        case format
        case channels
    }
    
    let format: AVAudioFormat
    let channels: NSArray
    
    convenience init(buffer: AVAudioPCMBuffer) {
        let channelCount = buffer.format.channelCount
        let channels = UnsafeBufferPointer(start: buffer.floatChannelData,
                                           count: Int(channelCount))
        let arr = NSMutableArray()
        for i in 0..<Int(channelCount) {
            let data = NSData(bytes: channels[i],
                              length: Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame))
            arr.add(data)
        }
        self.init(format: buffer.format, channels: arr)
    }
    
    init(format: AVAudioFormat, channels: NSArray) {
        self.format = format
        self.channels = channels
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(format, forKey: Keys.format.rawValue)
        coder.encode(channels, forKey: Keys.channels.rawValue)
    }
    
    required convenience init?(coder: NSCoder) {
        guard
            let format = coder.decodeObject(of: AVAudioFormat.self, forKey: Keys.format.rawValue),
            let channels = coder.decodeObject(of: NSArray.self, forKey: Keys.channels.rawValue)
        else {
            return nil
        }
        self.init(format: format, channels: channels)
    }
}
