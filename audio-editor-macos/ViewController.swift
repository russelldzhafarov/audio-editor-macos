//
//  ViewController.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import Combine
import AVFoundation

class ViewController: NSViewController {
    
    @IBOutlet weak var hintLabel: NSTextField!
    @IBOutlet weak var hintImageView: NSImageView!
    @IBOutlet weak var currentTimeLabel: NSTextField!
    @IBOutlet weak var selectionStartTimeLabel: NSTextField!
    @IBOutlet weak var selectionEndTimeLabel: NSTextField!
    @IBOutlet weak var selectionDurationLabel: NSTextField!
    @IBOutlet weak var statusLabel: NSTextField!
    
    @IBOutlet weak var rulerView: RulerView!
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet weak var waveformView: WaveformView!
    
    var viewModel: ViewModel?
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            guard let viewModel = representedObject as? ViewModel else { return }
            self.viewModel = viewModel
            
            rulerView.viewModel = viewModel
            overlayView.viewModel = viewModel
            waveformView.viewModel = viewModel
            
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
                    self?.statusLabel.stringValue = newValue ? "MP3  |  \((self?.viewModel?.sampleRate ?? 0.0) / Double(1000)) kHz  |  \(self?.viewModel?.channelCount == 2 ? "Stereo" : "Mono")  |  \(self?.viewModel?.duration.mmss() ?? "") min" : "Drop audio file to timeline or hit Cmd + O."
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
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.forEach{ $0.cancel() }
        cancellables.removeAll()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    @IBAction func actionBackwardEnd(_ sender: Any) {
        viewModel?.stop()
    }
    @IBAction func actionBackward(_ sender: Any) {
    }
    @IBAction func actionPlay(_ sender: Any) {
        viewModel?.play()
    }
    @IBAction func actionForward(_ sender: Any) {
    }
    @IBAction func actionRepeat(_ sender: Any) {
    }
}
