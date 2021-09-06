//
//  SelectionLayer.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 06.09.2021.
//

import Cocoa

class SelectionLayer: CALayer {
    
    static var selectionColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.3)
    }
    
    var viewModel: EditorViewModel?
    
    override func draw(in ctx: CGContext) {
        ctx.setFillColor(SelectionLayer.selectionColor.cgColor)
        ctx.fill(bounds)
    }
}
