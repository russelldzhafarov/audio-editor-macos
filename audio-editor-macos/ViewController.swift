//
//  ViewController.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import Combine

extension NSImage.Name {
    static let play = NSImage.Name("play.fill")
    static let pause = NSImage.Name("pause.fill")
}

class ViewController: NSViewController {
    
    @IBOutlet weak var hintLabel: NSTextField!
    @IBOutlet weak var hintImageView: NSImageView!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var selectionStartTimeLabel: NSTextField!
    @IBOutlet weak var selectionEndTimeLabel: NSTextField!
    @IBOutlet weak var selectionDurationLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var playButton: NSButton!
    
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
                    
                    self?.selectionStartTimeLabel.stringValue = newValue.isEmpty ? "" : newValue.lowerBound.mmssms()
                    self?.selectionEndTimeLabel.stringValue = newValue.isEmpty ? "" : newValue.upperBound.mmssms()
                    self?.selectionDurationLabel.stringValue = newValue.isEmpty ? "" : (newValue.upperBound - newValue.lowerBound).mmssms()
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
            
            viewModel.$loaded
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.waveformView.needsDisplay = true
                    self?.overlayView.needsDisplay = true
                    self?.rulerView.needsDisplay = true
                    
                    self?.hintLabel.isHidden = newValue
                    self?.hintImageView.isHidden = newValue
                    
                    self?.statusLabel.isHidden = !newValue
                    self?.statusLabel.stringValue = self?.viewModel?.status ?? "--"
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
    @IBAction func actionBackwardEnd(_ sender: Any) {
        viewModel?.stop()
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
    @IBAction func actionRepeat(_ sender: Any) {
        viewModel?.looped.toggle()
    }
}
