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
    
    var viewModel: EditorViewModel?
    
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
            let power = self.power(at: time)
            
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
    
    private func power(at time: TimeInterval) -> Float {
        guard let viewModel = viewModel,
              viewModel.duration > .zero else { return .zero }
        
        let sampleRate = Double(viewModel.samples.count) / viewModel.duration
        
        let index = Int(time * sampleRate)
        
        guard viewModel.samples.indices.contains(index) else { return .zero }
        
        let power = viewModel.samples[index]
        
        let avgPower = 20 * log10(power)
        
        return scaledPower(power: avgPower)
    }
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return .zero
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return .zero
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
}
