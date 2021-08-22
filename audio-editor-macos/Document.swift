//
//  Document.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import AVFoundation

class Document: NSDocument {

    let viewModel = ViewModel()
    
    override init() {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: .main, bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: .document) as! WindowController
        self.addWindowController(windowController)
        
        undoManager?.levelsOfUndo = 10
        viewModel.undoManager = undoManager
        
        windowController.viewModel = viewModel
        windowController.contentViewController?.representedObject = viewModel
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        guard let pcmBuffer = viewModel.pcmBuffer else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
        
        try AVAudioFile(url: url, fromBuffer: pcmBuffer)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        viewModel.readAudioFile(at: url)
    }
}

