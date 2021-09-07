//
//  Document.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import AVFoundation

class Document: NSDocument {

    let viewModel = EditorViewModel()

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: .main, bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: .document) as! EditorWindowController
        self.addWindowController(windowController)
        
        undoManager?.levelsOfUndo = 10
        viewModel.undoManager = undoManager
        
        windowController.viewModel = viewModel
        windowController.contentViewController?.representedObject = viewModel
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        let file = try AVAudioFile(forReading: url)
        file.framePosition = 0
        
        guard let aBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length))
        else { throw AVError(.unknown) }
        
        try file.read(into: aBuffer)
        
        viewModel.pcmBuffer = aBuffer
        viewModel.fileFormat = file.fileFormat
        viewModel.processingFormat = file.processingFormat
        
        viewModel.samples = aBuffer.compressed()
        viewModel.selectedTimeRange = nil
        viewModel.currentTime = .zero
    }
}

