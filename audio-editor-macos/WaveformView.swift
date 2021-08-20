//
//  WaveformView.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Cocoa

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
        
        // Draw background
        ctx.setFillColor(NSColor.waveformBackgroundColor.cgColor)
        ctx.fill(bounds)
        
        let startTime = viewModel.visibleTimeRange.lowerBound
        let endTime = viewModel.visibleTimeRange.upperBound
        
        let duration = viewModel.visibleDur
        let oneSecWidth = bounds.width / CGFloat(duration)
        
        let frame = CGRect(x: .zero,
                           y: .zero,
                           width: CGFloat(viewModel.duration) * oneSecWidth,
                           height: bounds.height)
        
        let lineWidth = CGFloat(1)
        let stepInPx = CGFloat(1)
        
        let koeff = frame.width / stepInPx
        let stepInSec = viewModel.duration / Double(koeff)
        
        guard stepInSec > 0 else { return }
        
        var x = frame.origin.x
        for time in stride(from: startTime, to: endTime, by: stepInSec) {
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
