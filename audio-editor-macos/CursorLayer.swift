//
//  CursorLayer.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 06.09.2021.
//

import Cocoa

class CursorLayer: CALayer {
    
    static var cursorColor: NSColor {
        NSColor.systemRed
    }
    
    var viewModel: EditorViewModel?
    
    override func draw(in ctx: CGContext) {
        guard let viewModel = viewModel,
              viewModel.visibleTimeRange.contains(viewModel.player.currentTime) else { return }
        
        ctx.move(to: CGPoint(x: bounds.midX, y: .zero))
        ctx.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
        
        ctx.setStrokeColor(CursorLayer.cursorColor.cgColor)
        ctx.setLineWidth(CGFloat(1))
        ctx.strokePath()
    }
}
