//
//  TimelineView.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 06.09.2021.
//

import Cocoa

class TimelineView: NSView {
    
    override var mouseDownCanMoveWindow: Bool { false }
    override var isFlipped: Bool { true }
    
    weak var viewModel: EditorViewModel? {
        didSet {
            waveformLayer.viewModel = viewModel
            rulerLayer.viewModel = viewModel
            
            updateLayerFrames()
        }
    }
    
    override var frame: CGRect {
        didSet {
            updateLayerFrames()
        }
    }
    
    private let waveformLayer = WaveformLayer()
    private let selectionLayer = CALayer()
    private let cursorLayer = CALayer()
    private let rulerLayer = RulerLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    func setup() {
        wantsLayer = true
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        
        let rootLayer = CALayer()
        
        waveformLayer.contentsScale = scale
        rootLayer.addSublayer(waveformLayer)
        
        rulerLayer.contentsScale = scale
        rootLayer.addSublayer(rulerLayer)
        
        selectionLayer.backgroundColor = NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.3).cgColor
        selectionLayer.contentsScale = scale
        rootLayer.addSublayer(selectionLayer)
        
        cursorLayer.backgroundColor = NSColor.systemRed.cgColor
        cursorLayer.contentsScale = scale
        rootLayer.addSublayer(cursorLayer)
        
        layer = rootLayer
    }
    
    func updateLayerFrames() {
        guard let viewModel = viewModel,
              viewModel.duration > .zero else { return }
        
        updateRulerLayer()
        updateWaveformLayer()
        updateSelectionLayer()
        updateCursorLayer()
    }
    
    func updateCursorLayer() {
        guard let viewModel = viewModel,
              viewModel.duration > .zero else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let oneSecWidth = bounds.width / CGFloat(viewModel.duration)
        let cursorPos = CGFloat(viewModel.currentTime) * oneSecWidth
        cursorLayer.frame = NSRect(x: cursorPos,
                                   y: viewModel.rulerHeight,
                                   width: 1.0,
                                   height: bounds.height - viewModel.rulerHeight)
        cursorLayer.setNeedsDisplay()
        
        CATransaction.commit()
    }
    
    func updateRulerLayer() {
        guard let viewModel = viewModel,
              viewModel.duration > .zero else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        rulerLayer.frame = CGRect(x: .zero,
                                  y: .zero,
                                  width: bounds.width,
                                  height: viewModel.rulerHeight)
        rulerLayer.setNeedsDisplay()
        
        CATransaction.commit()
    }
    
    func updateWaveformLayer() {
        guard let viewModel = viewModel,
              viewModel.duration > .zero else { return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        waveformLayer.frame = CGRect(x: .zero,
                                     y: viewModel.rulerHeight,
                                     width: bounds.width,
                                     height: bounds.height - viewModel.rulerHeight)
        waveformLayer.setNeedsDisplay()
        
        CATransaction.commit()
    }
    
    func updateSelectionLayer() {
        guard let viewModel = viewModel,
              viewModel.duration > .zero,
              let selectedTimeRange = viewModel.selectedTimeRange,
              !selectedTimeRange.isEmpty else { selectionLayer.isHidden = true; return }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let oneSecWidth = bounds.width / CGFloat(viewModel.duration)
        let startPos = CGFloat(selectedTimeRange.lowerBound) * oneSecWidth
        let endPos = CGFloat(selectedTimeRange.upperBound) * oneSecWidth
        
        selectionLayer.isHidden = false
        selectionLayer.frame = CGRect(x: startPos,
                                      y: viewModel.rulerHeight,
                                      width: endPos - startPos,
                                      height: bounds.height - viewModel.rulerHeight)
        selectionLayer.setNeedsDisplay()
        
        CATransaction.commit()
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let viewModel = viewModel,
              viewModel.duration > .zero else { return }
        
        let start = convert(event.locationInWindow, from: nil)
        
        let startTime = viewModel.duration * Double(start.x) / Double(bounds.width)
        
        while true {
            guard let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            
            let end = convert(nextEvent.locationInWindow, from: nil)
            
            if Int(start.x) == Int(end.x) && Int(start.y) == Int(end.y) {
                viewModel.selectedTimeRange = nil
                viewModel.currentTime = startTime.clamped(to: .zero ... viewModel.duration)
                
            } else {
                
                let endTime = viewModel.duration * Double(end.x) / Double(bounds.width)
                
                if startTime < endTime {
                    viewModel.selectedTimeRange = (startTime ... endTime).clamped(to: .zero ... viewModel.duration)
                    viewModel.currentTime = startTime.clamped(to: .zero ... viewModel.duration)
                    
                } else if startTime > endTime {
                    viewModel.selectedTimeRange = (endTime ... startTime).clamped(to: .zero ... viewModel.duration)
                    viewModel.currentTime = endTime.clamped(to: .zero ... viewModel.duration)
                    
                } else {
                    viewModel.selectedTimeRange = nil
                    viewModel.currentTime = startTime.clamped(to: .zero ... viewModel.duration)
                }
            }
            
            if nextEvent.type == .leftMouseUp {
                viewModel.seek(to: viewModel.currentTime)
                break
            }
        }
    }
}
