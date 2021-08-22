//
//  AppDelegate.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import AVFoundation
import Accelerate

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    func applicationWillTerminate(_ notification: Notification) {
        if NSPasteboard.general.data(forType: AVAudioPCMBuffer.pbType)?.isEmpty == false {
            NSPasteboard.general.clearContents()
        }
    }
}

public extension Array where Element == Float {
    /// Takes an array of floating point values and down samples it to have a lesser number of samples
    /// Returns an array of downsampled floating point values
    ///
    /// Parameters:
    ///   - sampleCount: the number of samples we will downsample the array to
    func downSample(to sampleCount: Int = 128) -> [Element] {
        let inputSampleCount = self.count
        let inputLength = vDSP_Length(inputSampleCount)

        let filterLength: vDSP_Length = 2
        let filter = [Float](repeating: 1 / Float(filterLength), count: Int(filterLength))

        let decimationFactor = inputSampleCount / sampleCount
        let outputLength = vDSP_Length((inputLength - filterLength) / vDSP_Length(decimationFactor))

        var outputFloats = [Float](repeating: 0, count: Int(outputLength))
        vDSP_desamp(self,
                    decimationFactor,
                    filter,
                    &outputFloats,
                    outputLength,
                    filterLength)
        
        return outputFloats
    }
}

extension RangeReplaceableCollection where Iterator.Element: ExpressibleByIntegerLiteral {
    /// Initialize array with zeros, ~10x faster than append for array of size 4096
    /// - parameter count: Number of elements in the array
    public init(zeros count: Int) {
        self.init(repeating: 0, count: count)
    }
}

extension TimeInterval {
    func mmss() -> String {
        let m: Int = Int(self) / 60
        let s: Int = Int(self) % 60
        return String(format: "%0d:%02d", m, s)
    }
    
    func mmssms() -> String {
        let m: Int = Int(self) / 60
        let s: Int = Int(self) % 60
        let ms: Int = Int((truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%0d:%02d,%02d", m, s, ms/10)
    }
    
    func hhmmssms() -> String {
        let h: Int = Int(self / 3600)
        let m: Int = Int(self) / 60
        let s: Int = Int(self) % 60
        let ms: Int = Int((truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%02d", h, m, s, ms)
    }
}

extension Double {
    func floor(nearest: Double) -> Double {
        let intDiv = Double(Int(self / nearest))
        return intDiv * nearest
    }
    func round(nearest: Double) -> Double {
        let n = 1/nearest
        let numberToRound = self * n
        return numberToRound.rounded() / n
    }
}

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

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension NSColor {
    static var windowBackgroundColor: NSColor {
        NSColor(red: 39.0/255.0, green: 42.0/255.0, blue: 54.0/255.0, alpha: 1.0)
    }
    static var waveformColor: NSColor {
        NSColor.systemTeal
    }
    static var waveformBackgroundColor: NSColor {
        NSColor(red: 30.0/255.0, green: 31.0/255.0, blue: 40.0/255.0, alpha: 1.0)
    }
    static var cursorColor: NSColor {
        NSColor.systemRed
    }
    static var selectionColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.3)
    }
    static var highlightColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.2)
    }
    static var rulerColor: NSColor {
        NSColor(red: 83.0/255.0, green: 89.0/255.0, blue: 105.0/255.0, alpha: 1.0)
    }
    static var rulerLabelColor: NSColor {
        NSColor(red: 142.0/255.0, green: 150.0/255.0, blue: 171.0/255.0, alpha: 1.0)
    }
}

extension NSToolbar.Identifier {
    static let toolbarIdentifier = NSToolbar.Identifier("MainWindowToolbarIdentifier")
}

extension NSToolbarItem.Identifier {
    static let undo = NSToolbarItem.Identifier(rawValue: "undoToolbarItemIdentifier")
    static let redo = NSToolbarItem.Identifier(rawValue: "redoToolbarItemIdentifier")
    static let cut = NSToolbarItem.Identifier(rawValue: "cutToolbarItemIdentifier")
    static let copy = NSToolbarItem.Identifier(rawValue: "copyToolbarItemIdentifier")
    static let paste = NSToolbarItem.Identifier(rawValue: "pasteToolbarItemIdentifier")
    static let delete = NSToolbarItem.Identifier(rawValue: "deleteToolbarItemIdentifier")
}

extension NSImage.Name {
    static let undo = NSImage.Name("arrow.uturn.backward")
    static let redo = NSImage.Name("arrow.uturn.forward")
    static let cut = NSImage.Name("scissors")
    static let copy = NSImage.Name("doc.on.clipboard")
    static let paste = NSImage.Name("doc.on.doc")
    static let delete = NSImage.Name("trash")
    static let play = NSImage.Name("play.fill")
    static let pause = NSImage.Name("pause.fill")
}

extension NSStoryboard.Name {
    static let main = NSStoryboard.Name("Main")
}

extension NSStoryboard.SceneIdentifier {
    static let document = NSStoryboard.SceneIdentifier("Document Window Controller")
}
