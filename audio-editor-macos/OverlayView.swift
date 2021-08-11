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
    static var highlightColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.2)
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
        guard let viewModel = viewModel else { return }
        
        let duration = viewModel.visibleTimeRange.upperBound - viewModel.visibleTimeRange.lowerBound
        let secPerPx = CGFloat(duration) / bounds.width
        
        let deltaPixels = event.deltaX < 0
            ? min(-event.deltaX * secPerPx,
                  CGFloat(viewModel.duration - viewModel.visibleTimeRange.upperBound))
            : min(event.deltaX * secPerPx,
                  CGFloat(viewModel.visibleTimeRange.lowerBound)) * -1
        
        if deltaPixels != 0 {
            viewModel.visibleTimeRange = viewModel.visibleTimeRange.lowerBound + Double(deltaPixels) ..< viewModel.visibleTimeRange.upperBound + Double(deltaPixels)
        }
    }
    override func magnify(with event: NSEvent) {
        guard let viewModel = viewModel else { return }
        
        let scale = CGFloat(1) + event.magnification
        
        let duration = viewModel.visibleTimeRange.upperBound - viewModel.visibleTimeRange.lowerBound
        let newDuration = duration / Double(scale)
        
        let loc = convert(event.locationInWindow, from: nil)
        let time = viewModel.visibleTimeRange.lowerBound + (duration * Double(loc.x) / Double(bounds.width))
        
        let startTime = time - ((time - viewModel.visibleTimeRange.lowerBound) / Double(scale))
        let endTime = startTime + newDuration
        
        guard startTime < endTime else { return }
        
        viewModel.visibleTimeRange = (startTime ..< endTime).clamped(to: 0 ..< viewModel.duration)
    }
    override func mouseDown(with event: NSEvent) {
        guard let viewModel = viewModel else { return }
        
        let start = convert(event.locationInWindow, from: nil)
        
        let duration = viewModel.visibleTimeRange.upperBound - viewModel.visibleTimeRange.lowerBound
        let startTime = viewModel.visibleTimeRange.lowerBound + (duration * Double(start.x) / Double(bounds.width))
        
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            
            let end = convert(nextEvent.locationInWindow, from: nil)
            
            if start.equalTo(end) {
                viewModel.selectedTimeRange = 0.0 ..< 0.0
                viewModel.currentTime = startTime
                
                viewModel.seek(to: startTime)
                
            } else {
                
                let endTime = viewModel.visibleTimeRange.lowerBound + (duration * Double(end.x) / Double(bounds.width))
                
                if startTime < endTime {
                    viewModel.selectedTimeRange = startTime ..< endTime
                    viewModel.currentTime = startTime
                    
                } else if endTime > startTime {
                    viewModel.selectedTimeRange = endTime ..< startTime
                    viewModel.currentTime = endTime
                    
                } else {
                    viewModel.selectedTimeRange = 0.0 ..< 0.0
                    viewModel.currentTime = startTime
                    
                    viewModel.seek(to: startTime)
                }
            }
            
            if nextEvent.type == .leftMouseUp {
                break
            }
        }
    }
    
    // MARK: - Drag & Drop
    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        guard pboard.types?.contains(.fileURL) == true else { return NSDragOperation() }
        
        viewModel?.highlighted = true
        
        return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        viewModel?.highlighted = false
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard
        guard pboard.types?.contains(.fileURL) == true,
              let fileURL = NSURL(from: pboard) else { return false }
        
        viewModel?.highlighted = false
        viewModel?.openAudioFile(at: fileURL as URL)
        
        return true
    }
    
    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
        guard let viewModel = viewModel,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw highlighting
        if viewModel.highlighted {
            ctx.setFillColor(NSColor.highlightColor.cgColor)
            ctx.fill(bounds)
        }
        
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
