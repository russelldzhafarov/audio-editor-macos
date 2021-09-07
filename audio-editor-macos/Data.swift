//
//  Data.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 07.09.2021.
//

import AVFoundation

extension Data {
    init(buffer: AVAudioPCMBuffer) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
    init(pcmBuffer: AVAudioPCMBuffer) {
        let channelCount = pcmBuffer.format.channelCount
        let channels = UnsafeBufferPointer(start: pcmBuffer.floatChannelData,
                                           count: Int(channelCount))
        self.init(bytes: channels[0],
                  count: Int(pcmBuffer.frameCapacity * pcmBuffer.format.streamDescription.pointee.mBytesPerFrame))
    }
}

extension NSData {
    convenience init(buffer: AVAudioPCMBuffer) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData, length: Int(audioBuffer.mDataByteSize))
    }
}
