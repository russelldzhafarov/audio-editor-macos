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

    override var isDocumentEdited: Bool { false }
    
    // This disables auto save.
    override class var autosavesInPlace: Bool { false }
    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: .main, bundle: nil)
        if let editorWindowController = storyboard.instantiateController(withIdentifier: .document) as? EditorWindowController {
            addWindowController(editorWindowController)
            
            undoManager?.levelsOfUndo = 10
            viewModel.undoManager = undoManager
            
            editorWindowController.viewModel = viewModel
            
            if let vc = editorWindowController.contentViewController {
                vc.representedObject = viewModel
            }
        }
    }
    
    // This enables asynchronous reading.
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        let file = try AVAudioFile(forReading: url)
        file.framePosition = 0
        
        guard let aBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: AVAudioFrameCount(file.length))
        else { throw AVError(.unknown) }
        
        try file.read(into: aBuffer)
        
        viewModel.fileURL = url
        viewModel.pcmBuffer = aBuffer
        viewModel.fileFormat = file.fileFormat
        viewModel.processingFormat = file.processingFormat
        
        viewModel.samples = aBuffer.compressed()
        viewModel.selectedTimeRange = nil
        viewModel.currentTime = .zero
        
        self.fileURL = nil
    }
}

