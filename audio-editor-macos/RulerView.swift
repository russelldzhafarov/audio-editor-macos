//
//  RulerView.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Cocoa

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
}
extension NSColor {
    static var rulerColor: NSColor {
        NSColor(red: 63.0/255.0, green: 69.0/255.0, blue: 85.0/255.0, alpha: 1.0)
    }
    static var rulerLabelColor: NSColor {
        NSColor(red: 142.0/255.0, green: 150.0/255.0, blue: 171.0/255.0, alpha: 1.0)
    }
}

class RulerView: NSView {
    
    // MARK: - Vars
    var viewModel: ViewModel?
    
    let attributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: NSColor.rulerLabelColor,
        .font: NSFont.systemFont(ofSize: CGFloat(13))
    ]
    
    // MARK: - Overrides
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
        guard let viewModel = viewModel,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        guard !viewModel.visibleTimeRange.isEmpty else {
            ctx.setFillColor(NSColor.waveformBackgroundColor.cgColor)
            ctx.fill(bounds)
            return
        }
        
        let startTime = viewModel.visibleTimeRange.lowerBound
        let endTime = viewModel.visibleTimeRange.upperBound
        
        let duration = endTime - startTime
        let pxPerSec = bounds.width / CGFloat(duration)
        
        let stepInSeconds: TimeInterval
        switch pxPerSec {
        case 0 ..< 10: stepInSeconds = 10
        case 10 ..< 15: stepInSeconds = 5
        case 15 ..< 50: stepInSeconds = 3
        case 50 ..< 100: stepInSeconds = 1
        case 100 ..< 200: stepInSeconds = 0.5
        default: stepInSeconds = 0.25
        }
        
        let fixedStartTime = startTime.floor(nearest: stepInSeconds)
        
        var x = CGFloat(fixedStartTime - startTime) * pxPerSec
        for time in stride(from: fixedStartTime, to: endTime, by: stepInSeconds) {
            
            NSString(string: stepInSeconds < 1 ? time.mmssms() : time.mmss())
                .draw(at: NSPoint(x: x + CGFloat(4), y: CGFloat(2)),
                      withAttributes: attributes)
            
            ctx.move(to: CGPoint(x: x,
                                 y: bounds.height - CGFloat(8)))
            
            ctx.addLine(to: CGPoint(x: x,
                                    y: bounds.height))
            
            x += pxPerSec * CGFloat(stepInSeconds)
        }
        
        ctx.setLineWidth(CGFloat(1))
        ctx.setStrokeColor(NSColor.rulerColor.cgColor)
        ctx.strokePath()
    }
}
