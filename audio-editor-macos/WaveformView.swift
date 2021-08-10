//
//  WaveformView.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Cocoa

extension NSColor {
    static var waveformColor: NSColor {
        NSColor(red: 178.0/255.0, green: 199.0/255.0, blue: 233.0/255.0, alpha: 1.0)
    }
    static var waveformBackgroundColor: NSColor {
        NSColor(red: 65.0/255.0, green: 115.0/255.0, blue: 167.0/255.0, alpha: 1.0)
    }
}

class WaveformView: NSView {
    
    // MARK: - Vars
    var viewModel: ViewModel?
    
    // MARK: - Overrides
    public override var isFlipped: Bool {
        return true
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let viewModel = viewModel,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.setFillColor(NSColor.waveformBackgroundColor.cgColor)
        ctx.fill(bounds)
        
        // Drawing code here.
        let lineWidth = CGFloat(1.5)
        let stepInPx = CGFloat(3)
        
        let koeff = bounds.width / stepInPx
        let stepInSec = viewModel.duration / Double(koeff)
        
        guard stepInSec > 0 else { return }
        
        var x = CGFloat(0)
        for time in stride(from: 0.0, to: viewModel.duration, by: stepInSec) {
            guard time < viewModel.duration else { continue }
            
            let power = viewModel.power(at: time)
            
            let heigth = max(CGFloat(1),
                             CGFloat(power) * (bounds.height/2))
            
            ctx.move(to: CGPoint(x: x,
                                 y: bounds.midY + heigth))
            
            ctx.addLine(to: CGPoint(x: x,
                                    y: bounds.midY - heigth))
            
            x += stepInPx
        }
        
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(NSColor.waveformColor.cgColor)
        ctx.strokePath()
    }
    
}
