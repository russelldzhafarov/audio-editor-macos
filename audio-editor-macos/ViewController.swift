//
//  ViewController.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import Combine

class ViewController: NSViewController {
    
    @IBOutlet weak var hintLabel: NSTextField!
    @IBOutlet weak var hintImageView: NSImageView!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var selectionStartTimeLabel: NSTextField!
    @IBOutlet weak var selectionEndTimeLabel: NSTextField!
    @IBOutlet weak var selectionDurationLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var fileFormatLabel: NSTextField!
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var progressView: NSView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var rulerView: RulerView!
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet weak var waveformView: WaveformView!
    
    var viewModel: ViewModel? {
        representedObject as? ViewModel
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.forEach{ $0.cancel() }
        cancellables.removeAll()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            guard let viewModel = representedObject as? ViewModel,
                  isViewLoaded else { return }
            
            rulerView.viewModel = viewModel
            overlayView.viewModel = viewModel
            waveformView.viewModel = viewModel
            
            viewModel.$error
                .receive(on: DispatchQueue.main)
                .sink { newValue in
                    if let newValue = newValue {
                        let alert = NSAlert()
                        alert.alertStyle = .critical
                        alert.messageText = "Something went wrong!"
                        alert.informativeText = newValue.localizedDescription
                        alert.runModal()
                    }
                }
                .store(in: &cancellables)
            
            viewModel.$playerState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    switch newValue {
                    case .stopped:
                        self?.playButton.image = NSImage(systemSymbolName: .play, accessibilityDescription: "")
                    case .paused:
                        self?.playButton.image = NSImage(systemSymbolName: .play, accessibilityDescription: "")
                    case .playing:
                        self?.playButton.image = NSImage(systemSymbolName: .pause, accessibilityDescription: "")
                    }
                }
                .store(in: &cancellables)
            
            viewModel.$currentTime
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.overlayView.needsDisplay = true
                    
                    self?.currentTimeLabel.stringValue = newValue.hhmmssms()
                }
                .store(in: &cancellables)
            
            viewModel.$selectedTimeRange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.overlayView.needsDisplay = true
                    
                    if let newValue = newValue {
                        self?.selectionStartTimeLabel.stringValue = newValue.lowerBound.mmssms()
                        self?.selectionEndTimeLabel.stringValue = newValue.upperBound.mmssms()
                        self?.selectionDurationLabel.stringValue = (newValue.upperBound - newValue.lowerBound).mmssms()
                        
                    } else {
                        self?.selectionStartTimeLabel.stringValue = ""
                        self?.selectionEndTimeLabel.stringValue = ""
                        self?.selectionDurationLabel.stringValue = ""
                    }
                }
                .store(in: &cancellables)
            
            viewModel.$visibleTimeRange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.waveformView.needsDisplay = true
                    self?.overlayView.needsDisplay = true
                    self?.rulerView.needsDisplay = true
                }
                .store(in: &cancellables)
            
            viewModel.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.waveformView.needsDisplay = true
                    self?.overlayView.needsDisplay = true
                    self?.rulerView.needsDisplay = true
                    
                    switch newValue {
                    case .empty:
                        self?.progressView.isHidden = true
                        
                        self?.hintLabel.isHidden = false
                        self?.hintImageView.isHidden = false
                        
                        self?.statusLabel.stringValue = "Drop media file to timeline or hit Cmd + O."
                        self?.fileFormatLabel.stringValue = ""
                        
                    case .processing:
                        self?.progressView.isHidden = false
                        self?.progressIndicator.startAnimation(nil)
                        
                        self?.hintLabel.isHidden = true
                        self?.hintImageView.isHidden = true
                        
                        self?.statusLabel.stringValue = "Processing..."
                        self?.fileFormatLabel.stringValue = self?.viewModel?.status ?? ""
                        
                    case .ready:
                        self?.progressView.isHidden = true
                        self?.progressIndicator.stopAnimation(nil)
                        
                        self?.hintLabel.isHidden = true
                        self?.hintImageView.isHidden = true
                        
                        self?.statusLabel.stringValue = "Ready"
                        self?.fileFormatLabel.stringValue = self?.viewModel?.status ?? ""
                    }
                }
                .store(in: &cancellables)
            
            viewModel.$highlighted
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.overlayView.needsDisplay = true
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Actions
    override func selectAll(_ sender: Any?) {
        guard let viewModel = viewModel else { return }
        viewModel.selectedTimeRange = 0.0 ..< viewModel.duration
    }
    @IBAction func actionBackwardEnd(_ sender: Any) {
        viewModel?.backwardEnd()
    }
    @IBAction func actionBackward(_ sender: Any) {
        viewModel?.backward()
    }
    @IBAction func actionPlay(_ sender: Any) {
        viewModel?.play()
    }
    @IBAction func actionForward(_ sender: Any) {
        viewModel?.forward()
    }
    @IBAction func actionForwardEnd(_ sender: Any) {
        viewModel?.forwardEnd()
    }
}
