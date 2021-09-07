//
//  EditorViewController.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import Combine

class EditorViewController: NSViewController {
    
    @IBOutlet weak var timelineView: TimelineView!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var selectionStartTimeLabel: NSTextField!
    @IBOutlet weak var selectionEndTimeLabel: NSTextField!
    @IBOutlet weak var selectionDurationLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var fileFormatLabel: NSTextField!
    @IBOutlet weak var playButton: NSButton!
    
    var viewModel: EditorViewModel? {
        representedObject as? EditorViewModel
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.forEach{ $0.cancel() }
        cancellables.removeAll()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            guard let viewModel = representedObject as? EditorViewModel,
                  isViewLoaded else { return }
            
            timelineView.viewModel = viewModel
            
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
                    case .playing:
                        self?.playButton.image = NSImage(systemSymbolName: .pause, accessibilityDescription: "")
                    }
                }
                .store(in: &cancellables)
            
            viewModel.$currentTime
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.timelineView.updateCursorLayer()
                    
                    self?.currentTimeLabel.stringValue = newValue.hhmmssms()
                }
                .store(in: &cancellables)
            
            viewModel.$selectedTimeRange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.timelineView.updateSelectionLayer()
                    
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
            
            viewModel.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    switch newValue {
                    case .processing:
                        self?.statusLabel.stringValue = "Processing..."
                        self?.fileFormatLabel.stringValue = self?.viewModel?.status ?? ""
                        
                        let storyboard = NSStoryboard(name: .main, bundle: nil)
                        let progressViewController = storyboard.instantiateController(withIdentifier: .progressViewController) as! ProgressViewController
                        
                        progressViewController.view.frame = NSRect(origin: .zero, size: self?.view.window?.frame.size ?? .zero)
                        
                        let overlayWindow = NSWindow(contentRect: self?.view.window?.frame ?? .zero,
                                                     styleMask: .borderless,
                                                     backing: .buffered,
                                                     defer: false)
                        
                        overlayWindow.contentViewController = progressViewController
                        overlayWindow.backgroundColor = .clear
                        overlayWindow.isOpaque = false
                        
                        self?.view.window?.addChildWindow(overlayWindow, ordered: .above)
                        
                    case .ready:
                        self?.timelineView.updateLayerFrames()
                        
                        self?.statusLabel.stringValue = "Ready"
                        self?.fileFormatLabel.stringValue = self?.viewModel?.status ?? ""
                        
                        self?.view.window?.childWindows?.forEach{ self?.view.window?.removeChildWindow($0); $0.orderOut(nil) }
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Actions
    override func selectAll(_ sender: Any?) {
        viewModel?.selectAll()
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
