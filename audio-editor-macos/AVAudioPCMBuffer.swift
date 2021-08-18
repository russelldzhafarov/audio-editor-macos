//
//  AVAudioPCMBuffer.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation

extension AVAudioPCMBuffer {
    
    var duration: TimeInterval {
        Double(frameLength) / format.sampleRate
    }
    var sampleRate: Double {
        format.sampleRate
    }
    var channelCount: AVAudioChannelCount {
        format.channelCount
    }
    
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
    
    func paste(buffer: AVAudioPCMBuffer, at time: TimeInterval) -> AVAudioPCMBuffer? {
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if time > 0.0 {
            guard let segment1 = AudioService.copy(buffer: self, timeRange: 0.0..<time) else {
                return nil
            }
            
            buffers.append(segment1)
        }
        
        buffers.append(buffer)
        
        // Copy second part
        if time < self.duration {
            guard let segment2 = AudioService.copy(buffer: self, timeRange: time..<self.duration) else {
                return nil
            }
            
            buffers.append(segment2)
        }
        
        // Concatenate
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        guard let resBuffer = AVAudioPCMBuffer(pcmFormat: self.format, frameCapacity: frameCapacity) else {
            return nil
        }
        
        buffers.forEach { resBuffer.append($0) }
        
        return resBuffer
    }
    
    func remove(startTime: TimeInterval, endTime: TimeInterval) -> AVAudioPCMBuffer? {
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if startTime > 0.0 {
            let from1 = AVAudioFramePosition(1)
            let to1 = AVAudioFramePosition(startTime * sampleRate)
            
            guard let segment1 = segment(from: from1, to: to1) else {
                return nil
            }
            
            buffers.append(segment1)
        }
        
        // Copy second part
        if endTime < duration {
            let from2 = AVAudioFramePosition(endTime * sampleRate)
            let to2 = AVAudioFramePosition(frameLength)
            
            guard let segment2 = segment(from: from2, to: to2) else {
                return nil
            }
            
            buffers.append(segment2)
        }
        
        // Concatenate
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        guard let resBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }
        
        buffers.forEach { resBuffer.append($0) }
        
        return resBuffer
    }
}
