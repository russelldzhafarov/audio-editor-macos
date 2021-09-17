//
//  WaveformLayer.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 06.09.2021.
//

import Cocoa

class WaveformLayer: CALayer {
    
    static var waveformColor: NSColor {
        NSColor.labelColor
    }
    static var waveformBackgroundColor: NSColor {
        NSColor(red: 30.0/255.0, green: 31.0/255.0, blue: 40.0/255.0, alpha: 0.3)
    }
    
    weak var viewModel: EditorViewModel?
    
    override func draw(in ctx: CGContext) {
        guard let viewModel = viewModel else { return }
        
        // Draw background
        ctx.setFillColor(WaveformLayer.waveformBackgroundColor.cgColor)
        ctx.fill(bounds)
        
        let oneSecWidth = bounds.width / CGFloat(viewModel.duration)
        
        let frame = CGRect(x: .zero,
                           y: .zero,
                           width: CGFloat(viewModel.duration) * oneSecWidth,
                           height: bounds.height)
        
        let lineWidth = CGFloat(1)
        let stepInPx = CGFloat(1)
        
        let koeff = frame.width / stepInPx
        let stepInSec = viewModel.duration / Double(koeff)
        
        guard stepInSec > 0 else { return }
        
        var x: CGFloat = .zero
        for time in stride(from: .zero, to: viewModel.duration, by: stepInSec) {
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
        ctx.setStrokeColor(WaveformLayer.waveformColor.cgColor)
        ctx.strokePath()
    }
}
