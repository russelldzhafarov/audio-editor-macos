//
//  AVAudioPCMBuffer.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

extension AVAudioPCMBuffer {
    
    convenience init?(data: Data, format: AVAudioFormat) {
        let streamDesc = format.streamDescription.pointee
        let frameCapacity = UInt32(data.count) / streamDesc.mBytesPerFrame
        
        self.init(pcmFormat: format, frameCapacity: frameCapacity)
        
        self.frameLength = self.frameCapacity
        
        let audioBuffer = self.audioBufferList.pointee.mBuffers
        
        data.withUnsafeBytes { bufferPointer in
            guard let addr = bufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: addr, byteCount: Int(audioBuffer.mDataByteSize))
        }
    }
    
    func segment(from startFrame: AVAudioFramePosition, to endFrame: AVAudioFramePosition) -> AVAudioPCMBuffer? {
        guard startFrame > 0 else { return nil }
        guard endFrame > startFrame else { return nil }
        guard endFrame <= frameLength else { return nil }
        
        let framesToCopy = AVAudioFrameCount(endFrame - startFrame)
        guard let segment = AVAudioPCMBuffer(pcmFormat: self.format, frameCapacity: framesToCopy) else { return nil }
        
        let sampleSize = self.format.streamDescription.pointee.mBytesPerFrame
        
        let srcPtr = UnsafeMutableAudioBufferListPointer(self.mutableAudioBufferList)
        let dstPtr = UnsafeMutableAudioBufferListPointer(segment.mutableAudioBufferList)
        for (src, dst) in zip(srcPtr, dstPtr) {
            memcpy(dst.mData,
                   src.mData?.advanced(by: Int(startFrame) * Int(sampleSize)),
                   Int(framesToCopy) * Int(sampleSize))
        }
        
        segment.frameLength = framesToCopy
        return segment
    }
    
    func append(_ buffer: AVAudioPCMBuffer) {
        append(buffer, startingFrame: 0, frameCount: buffer.frameLength)
    }
    
    func append(_ buffer: AVAudioPCMBuffer, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) {
        precondition(format == buffer.format, "Format mismatch")
        precondition(startingFrame + AVAudioFramePosition(frameCount) <= AVAudioFramePosition(buffer.frameLength), "Insufficient audio in buffer")
        precondition(frameLength + frameCount <= frameCapacity, "Insufficient space in buffer")
        
        let dst = floatChannelData!
        let src = buffer.floatChannelData!
        
        memcpy(dst.pointee.advanced(by: stride * Int(frameLength)),
               src.pointee.advanced(by: stride * Int(startingFrame)),
               Int(frameCount) * stride * MemoryLayout<Float>.size)
        
        frameLength += frameCount
    }
}
