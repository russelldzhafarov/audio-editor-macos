//
//  OverlayView.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Cocoa

extension NSColor {
    static var cursorColor: NSColor {
        NSColor.systemRed
    }
    static var selectionColor: NSColor {
        NSColor.cursorColor.withAlphaComponent(0.3)
    }
}

class OverlayView: NSView {
    
    // MARK: - Vars
    var viewModel: ViewModel?
    
    // MARK: - Overrides
    public override var isFlipped: Bool {
        return true
    }
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    // MARK: - Events
    override func scrollWheel(with event: NSEvent) {
        
    }
    override func magnify(with event: NSEvent) {
        
    }
    override func mouseDown(with event: NSEvent) {
        
    }
    
    // MARK: - Drag & Drop
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NSDragOperation()
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        false
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let viewModel = viewModel,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let startTime = viewModel.visibleTimeRange.lowerBound
        let endTime = viewModel.visibleTimeRange.upperBound
        
        let pxPerSec = bounds.width / CGFloat(endTime - startTime)
        
        // Draw selection
        if !viewModel.selectedTimeRange.isEmpty {
            let timeRange = viewModel.selectedTimeRange.clamped(to: viewModel.visibleTimeRange)
            
            guard !timeRange.isEmpty else { return }
            
            let duration = timeRange.upperBound - timeRange.lowerBound
            
            let startPos = CGFloat(timeRange.lowerBound - viewModel.visibleTimeRange.lowerBound) * pxPerSec
            
            ctx.setFillColor(NSColor.selectionColor.cgColor)
            ctx.fill(CGRect(x: startPos,
                            y: CGFloat(0),
                            width: CGFloat(duration) * pxPerSec,
                            height: bounds.height))
        }
        
        // Draw cursor
        if (startTime ..< endTime).contains(viewModel.currentTime) {
            
            let cursorPos = CGFloat(viewModel.currentTime - viewModel.visibleTimeRange.lowerBound) * pxPerSec
            
            ctx.move(to: CGPoint(x: cursorPos,
                                 y: CGFloat(0)))
            ctx.addLine(to: CGPoint(x: cursorPos,
                                    y: bounds.height))
            
            ctx.setStrokeColor(NSColor.cursorColor.cgColor)
            ctx.setLineWidth(CGFloat(1))
            ctx.strokePath()
        }
    }
}
