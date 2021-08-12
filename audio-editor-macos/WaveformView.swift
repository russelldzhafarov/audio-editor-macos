//
//  WaveformView.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Cocoa

extension NSColor {
    static var waveformColor: NSColor {
        NSColor(red: 65.0/255.0, green: 167.0/255.0, blue: 208.0/255.0, alpha: 1.0)
    }
    static var waveformBackgroundColor: NSColor {
        NSColor(red: 30.0/255.0, green: 31.0/255.0, blue: 40.0/255.0, alpha: 1.0)
    }
}

class WaveformView: NSView {
    
    // MARK: - Vars
    var viewModel: ViewModel?
    
    // MARK: - Overrides
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
        guard let viewModel = viewModel,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let startTime = viewModel.visibleTimeRange.lowerBound
        let endTime = viewModel.visibleTimeRange.upperBound
        
        let duration = endTime - startTime
        let pxPerSec = bounds.width / CGFloat(duration)
        
        let frame = CGRect(x: CGFloat(-startTime) * pxPerSec,
                           y: CGFloat(0),
                           width: CGFloat(viewModel.duration) * pxPerSec,
                           height: bounds.height)
        
        ctx.setFillColor(NSColor.waveformBackgroundColor.cgColor)
        ctx.fill(bounds)
        
        let lineWidth = CGFloat(1)
        let stepInPx = CGFloat(1)
        
        let koeff = frame.width / stepInPx
        let stepInSec = viewModel.duration / Double(koeff)
        
        guard stepInSec > 0 else { return }
        
        var x = frame.origin.x
        for time in stride(from: 0.0, to: viewModel.duration, by: stepInSec) {
            let power = viewModel.power(at: time)
            
            let heigth = max(CGFloat(1),
                             CGFloat(power) * (frame.height/2))
            
            ctx.move(to: CGPoint(x: x,
                                 y: frame.midY + heigth))
            
            ctx.addLine(to: CGPoint(x: x,
                                    y: frame.midY - heigth))
            
            x += stepInPx
        }
        
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(NSColor.waveformColor.cgColor)
        ctx.strokePath()
    }
    
}
