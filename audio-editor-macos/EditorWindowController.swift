//
//  EditorWindowController.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import AVFoundation

extension NSStoryboard.Name {
    static let main = NSStoryboard.Name("Main")
}

extension NSStoryboard.SceneIdentifier {
    static let document = NSStoryboard.SceneIdentifier("Document Window Controller")
    static let progressViewController = NSStoryboard.SceneIdentifier("ProgressViewController")
}

extension NSImage.Name {
    static let undo = NSImage.Name("arrow.uturn.backward")
    static let redo = NSImage.Name("arrow.uturn.forward")
    static let cut = NSImage.Name("scissors")
    static let copy = NSImage.Name("doc.on.clipboard")
    static let paste = NSImage.Name("doc.on.doc")
    static let delete = NSImage.Name("trash")
    static let play = NSImage.Name("play.fill")
    static let pause = NSImage.Name("pause.fill")
}

extension NSToolbar.Identifier {
    static let toolbarIdentifier = NSToolbar.Identifier("MainWindowToolbarIdentifier")
}

extension NSToolbarItem.Identifier {
    static let undo = NSToolbarItem.Identifier(rawValue: "undoToolbarItemIdentifier")
    static let redo = NSToolbarItem.Identifier(rawValue: "redoToolbarItemIdentifier")
    static let cut = NSToolbarItem.Identifier(rawValue: "cutToolbarItemIdentifier")
    static let copy = NSToolbarItem.Identifier(rawValue: "copyToolbarItemIdentifier")
    static let paste = NSToolbarItem.Identifier(rawValue: "pasteToolbarItemIdentifier")
    static let delete = NSToolbarItem.Identifier(rawValue: "deleteToolbarItemIdentifier")
}

class EditorWindowController: NSWindowController {

    var viewModel: EditorViewModel?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        let toolbar = NSToolbar(identifier: .toolbarIdentifier)
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.delegate = self
        
        window?.toolbar = toolbar
        
        window?.toolbarStyle = .unified
        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        
        window?.toolbar?.validateVisibleItems()
        window?.backgroundColor = NSColor.windowBackgroundColor
        window?.isMovableByWindowBackground = true
    }
    
    // MARK: - Toolbar Item Custom Actions
    @IBAction func undo(_ sender: Any) { viewModel?.undoManager?.undo() }
    @IBAction func redo(_ sender: Any) { viewModel?.undoManager?.redo() }
    @IBAction func cut(_ sender: Any) { viewModel?.cut() }
    @IBAction func copy(_ sender: Any) { viewModel?.copy() }
    @IBAction func paste(_ sender: Any) { viewModel?.paste() }
    @IBAction func delete(_ sender: Any) { viewModel?.delete() }
}

extension EditorWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(cut(_:)):
            return viewModel?.selectedTimeRange != nil
        case #selector(copy(_:)):
            return viewModel?.selectedTimeRange != nil
        case #selector(paste(_:)):
            return NSPasteboard.general.data(forType: AVAudioPCMBuffer.pbType)?.isEmpty == false
        case #selector(delete(_:)):
            return viewModel?.selectedTimeRange != nil
        default:
            return true
        }
    }
}

extension EditorWindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .undo:
            return viewModel?.undoManager?.canUndo == true
        case .redo:
            return viewModel?.undoManager?.canRedo == true
        case .cut:
            return viewModel?.selectedTimeRange != nil
        case .copy:
            return viewModel?.selectedTimeRange != nil
        case .paste:
            return NSPasteboard.general.data(forType: AVAudioPCMBuffer.pbType)?.isEmpty == false
        case .delete:
            return viewModel?.selectedTimeRange != nil
        default:
            return false
        }
    }
}

extension EditorWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.undo, .redo, .space, .cut, .copy, .paste, .delete, .flexibleSpace]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.undo, .redo, .cut, .copy, .paste, .delete, .space, .flexibleSpace]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        let label: String
        let action: Selector
        let symbolName: String
        switch itemIdentifier {
        case .undo:
            label = "Undo"
            action = #selector(undo(_:))
            symbolName = .undo
            
        case .redo:
            label = "Redo"
            action = #selector(redo(_:))
            symbolName = .redo
            
        case .cut:
            label = "Cut"
            action = #selector(cut(_:))
            symbolName = .cut
            
        case .copy:
            label = "Copy"
            action = #selector(copy(_:))
            symbolName = .copy
            
        case .paste:
            label = "Paste"
            action = #selector(paste(_:))
            symbolName = .paste
            
        case .delete:
            label = "Delete"
            action = #selector(delete(_:))
            symbolName = .delete
            
        default:
            return nil
        }
        
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.isBordered = true
        toolbarItem.target = self
        toolbarItem.action = action
        toolbarItem.label = label
        toolbarItem.paletteLabel = label
        toolbarItem.toolTip = label
        toolbarItem.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "")
        
        return toolbarItem
    }
}
