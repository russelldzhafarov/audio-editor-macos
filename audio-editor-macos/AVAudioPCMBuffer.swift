//
//  AVAudioPCMBuffer.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import AVFoundation
import Accelerate
import AppKit

extension AVAudioPCMBuffer {
    static let pbType = NSPasteboard.PasteboardType("com.russelldzhafarov.audio-editor-macos.audio.pbtype")
    
    func copy(to pasteboard: NSPasteboard) throws {
        let obj = AudioPasteboardData(buffer: self)
        let codedData = try NSKeyedArchiver.archivedData(withRootObject: obj, requiringSecureCoding: true)
        
        pasteboard.clearContents()
        pasteboard.declareTypes([AVAudioPCMBuffer.pbType], owner: nil)
        pasteboard.setData(codedData, forType: AVAudioPCMBuffer.pbType)
    }
    class func read(from pasteboard: NSPasteboard) throws -> AVAudioPCMBuffer? {
        guard let type = pasteboard.availableType(from: [AVAudioPCMBuffer.pbType]),
              type == AVAudioPCMBuffer.pbType,
              let data = pasteboard.data(forType: AVAudioPCMBuffer.pbType) else { return nil }
        
        guard let obj = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? AudioPasteboardData else {
            return nil
        }
        
        return AVAudioPCMBuffer(channelsData: obj.channels as! [NSData], format: obj.format)
    }
}

extension AVAudioFile {
    // Duration in seconds
    var duration: TimeInterval {
        Double(length) / fileFormat.sampleRate
    }
    
    // Convenience init to instantiate a file from an AVAudioPCMBuffer.
    convenience init(url: URL, fromBuffer buffer: AVAudioPCMBuffer) throws {
        try self.init(forWriting: url, settings: buffer.format.settings)

        // Write the buffer in file
        do {
            framePosition = 0
            try write(from: buffer)
        } catch let error as NSError {
            throw error
        }
    }
}

extension AVAudioPCMBuffer {
    func toNSData() -> [NSData] {
        let channelCount = Int(format.channelCount)
        let channels = UnsafeBufferPointer(start: floatChannelData,
                                           count: channelCount)
        
        var result: [NSData] = []
        for i in 0..<channelCount {
            let data = NSData(bytes: channels[i],
                              length: Int(self.frameCapacity * self.format.streamDescription.pointee.mBytesPerFrame))
            result.append(data)
        }
        return result
    }
    
    convenience init?(channelsData: [NSData], format: AVAudioFormat) {
        self.init(pcmFormat: format,
                  frameCapacity: UInt32(channelsData[0].length) / format.streamDescription.pointee.mBytesPerFrame)
        
        self.frameLength = self.frameCapacity
        let channels = UnsafeBufferPointer(start: self.floatChannelData, count: Int(self.format.channelCount))
        
        for i in 0..<Int(channelCount) {
            channelsData[i].getBytes(UnsafeMutableRawPointer(channels[i]),
                                     length: channelsData[i].length)
        }
    }
}

/// 2D array of stereo audio data
public typealias FloatChannelData = [[Float]]

extension AVAudioPCMBuffer {
    /// Returns audio data as an `Array` of `Float` Arrays.
    ///
    /// If stereo:
    /// - `floatChannelData?[0]` will contain an Array of left channel samples as `Float`
    /// - `floatChannelData?[1]` will contains an Array of right channel samples as `Float`
    public func toFloatChannelData() -> FloatChannelData? {
        // Do we have PCM channel data?
        guard let pcmFloatChannelData = floatChannelData else {
            return nil
        }

        let channelCount = Int(format.channelCount)
        let frameLength = Int(self.frameLength)
        let stride = self.stride

        // Preallocate our Array so we're not constantly thrashing while resizing as we append.
        var result = Array(repeating: [Float](zeros: frameLength), count: channelCount)

        // Loop across our channels...
        for channel in 0 ..< channelCount {
            // Make sure we go through all of the frames...
            for sampleIndex in 0 ..< frameLength {
                result[channel][sampleIndex] = pcmFloatChannelData[channel][sampleIndex * stride]
            }
        }

        return result
    }
}

extension AVAudioPCMBuffer {
    // Read the contents of the url into this buffer
    convenience init?(url: URL) throws {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        try self.init(file: file)
    }
    
    // Read entire file and return a new AVAudioPCMBuffer with its contents
    convenience init?(file: AVAudioFile) throws {
        file.framePosition = 0
        
        self.init(pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length))
        
        try file.read(into: self)
    }
}

extension AVAudioPCMBuffer {
    convenience init?(concatenating buffers: [AVAudioPCMBuffer]) {
        guard !buffers.isEmpty else { return nil }
        let frameCapacity = buffers.map{ $0.frameLength }.reduce(0, +)
        self.init(pcmFormat: buffers[0].format, frameCapacity: frameCapacity)
        buffers.forEach { self.append($0) }
    }
    
    /// Add to an existing buffer
    ///
    /// - Parameter buffer: Buffer to append
    public func append(_ buffer: AVAudioPCMBuffer) {
        self.append(buffer, startingFrame: 0, frameCount: buffer.frameLength)
    }

    /// Add to an existing buffer with specific starting frame and size
    /// - Parameters:
    ///   - buffer: Buffer to append
    ///   - startingFrame: Starting frame location
    ///   - frameCount: Number of frames to append
    public func append(_ buffer: AVAudioPCMBuffer, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) {
        precondition(format == buffer.format,
                     "Format mismatch")
        precondition(startingFrame + AVAudioFramePosition(frameCount) <= AVAudioFramePosition(buffer.frameLength),
                     "Insufficient audio in buffer")
        precondition(frameLength + frameCount <= frameCapacity,
                     "Insufficient space in buffer")
        
        for i in 0..<Int(channelCount) {
            guard let dst = floatChannelData?[i],
                  let src = buffer.floatChannelData?[i] else { continue }
            
            memcpy(dst.advanced(by: stride * Int(frameLength)),
                   src.advanced(by: stride * Int(startingFrame)),
                   Int(frameCount) * stride * MemoryLayout<Float>.size)
        }

        frameLength += frameCount
    }

    /// Copies data from another PCM buffer.  Will copy to the end of the buffer (frameLength), and
    /// increment frameLength. Will not exceed frameCapacity.
    ///
    /// - Parameter buffer: The source buffer that data will be copied from.
    /// - Parameter readOffset: The offset into the source buffer to read from.
    /// - Parameter frames: The number of frames to copy from the source buffer.
    /// - Returns: The number of frames copied.
    @discardableResult public func copy(from buffer: AVAudioPCMBuffer,
                                        readOffset: AVAudioFrameCount = 0,
                                        frames: AVAudioFrameCount = 0) -> AVAudioFrameCount {
        let remainingCapacity = frameCapacity - frameLength
        if remainingCapacity == 0 {
            print("AVAudioBuffer copy(from) - no capacity!")
            return 0
        }

        if format != buffer.format {
            print("AVAudioBuffer copy(from) - formats must match!")
            return 0
        }

        let totalFrames = Int(min(min(frames == 0 ? buffer.frameLength : frames, remainingCapacity),
                                  buffer.frameLength - readOffset))

        if totalFrames <= 0 {
            print("AVAudioBuffer copy(from) - No frames to copy!")
            return 0
        }
        
        let frameSize = Int(format.streamDescription.pointee.mBytesPerFrame)
        if let src = buffer.floatChannelData,
           let dst = floatChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(dst[channel] + Int(frameLength), src[channel] + Int(readOffset), totalFrames * frameSize)
            }
        } else if let src = buffer.int16ChannelData,
                  let dst = int16ChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(dst[channel] + Int(frameLength), src[channel] + Int(readOffset), totalFrames * frameSize)
            }
        } else if let src = buffer.int32ChannelData,
                  let dst = int32ChannelData {
            for channel in 0 ..< Int(format.channelCount) {
                memcpy(dst[channel] + Int(frameLength), src[channel] + Int(readOffset), totalFrames * frameSize)
            }
        } else {
            return 0
        }
        frameLength += AVAudioFrameCount(totalFrames)
        return AVAudioFrameCount(totalFrames)
    }

    /// Copy from a certain point tp the end of the buffer
    /// - Parameter startSample: Point to start copy from
    /// - Returns: an AVAudioPCMBuffer copied from a sample offset to the end of the buffer.
    public func copyFrom(startSample: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard startSample < frameLength,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength - startSample) else {
            return nil
        }
        let framesCopied = buffer.copy(from: self, readOffset: startSample)
        return framesCopied > 0 ? buffer : nil
    }

    /// Copy from the beginner of a buffer to a certain number of frames
    /// - Parameter count: Length of frames to copy
    /// - Returns: an AVAudioPCMBuffer copied from the start of the buffer to the specified endSample.
    public func copyTo(count: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
            return nil
        }
        let framesCopied = buffer.copy(from: self, readOffset: 0, frames: min(count, frameLength))
        return framesCopied > 0 ? buffer : nil
    }

    /// Extract a portion of the buffer
    ///
    /// - Parameter startTime: The time of the in point of the extraction
    /// - Parameter endTime: The time of the out point
    /// - Returns: A new edited AVAudioPCMBuffer
    public func extract(from startTime: TimeInterval,
                        to endTime: TimeInterval) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let startSample = AVAudioFrameCount(startTime * sampleRate)
        var endSample = AVAudioFrameCount(endTime * sampleRate)

        if endSample == 0 {
            endSample = frameLength
        }

        let frameCapacity = endSample - startSample

        guard frameCapacity > 0 else {
            print("startSample must be before endSample")
            return nil
        }

        guard let editedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            print("Failed to create edited buffer")
            return nil
        }

        guard editedBuffer.copy(from: self, readOffset: startSample, frames: frameCapacity) > 0 else {
            print("Failed to write to edited buffer")
            return nil
        }
        
        return editedBuffer
    }
}

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
    
    func paste(buffer: AVAudioPCMBuffer, at time: TimeInterval) -> AVAudioPCMBuffer? {
        
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if time > 0.0 {
            guard let segment1 = self.extract(from: 0.0, to: time) else {
                return nil
            }
            
            buffers.append(segment1)
        }
        
        buffers.append(buffer)
        
        // Copy second part
        if time < self.duration {
            guard let segment2 = self.extract(from: time, to: self.duration) else {
                return nil
            }
            
            buffers.append(segment2)
        }
        
        return AVAudioPCMBuffer(concatenating: buffers)
    }
    
    func remove(startTime: TimeInterval, endTime: TimeInterval) -> AVAudioPCMBuffer? {
        var buffers = [AVAudioPCMBuffer]()
        
        // Copy first part
        if startTime > 0.0 {
            guard let segment1 = extract(from: 0, to: startTime) else {
                return nil
            }
            
            buffers.append(segment1)
        }
        
        // Copy second part
        if endTime < duration {
            guard let segment2 = extract(from: endTime, to: duration) else {
                return nil
            }
            
            buffers.append(segment2)
        }
        
        return AVAudioPCMBuffer(concatenating: buffers)
    }
    
    func compressed(_ compression: Int = 1000) -> [Float] {
        
        let inputSignal = Array(UnsafeBufferPointer(start: self.floatChannelData?[0],
                                                    count: Int(self.frameLength)))
        
        var processingBuffer = [Float](repeating: 0.0,
                                       count: Int(inputSignal.count))
        
        vDSP_vabs(inputSignal,
                  1,
                  &processingBuffer,
                  1,
                  vDSP_Length(inputSignal.count))
        
        let filter = [Float](repeating: 1.0 / Float(compression),
                             count: Int(compression))
        
        let downSampledLength = inputSignal.count / compression
        
        var downSampledData = [Float](repeating: 0.0,
                                      count: downSampledLength)
        
        vDSP_desamp(processingBuffer,
                    vDSP_Stride(compression),
                    filter,
                    &downSampledData,
                    vDSP_Length(downSampledLength),
                    vDSP_Length(compression))
        
        return downSampledData
    }
}
