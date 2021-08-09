//
//  WindowController.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa

fileprivate extension NSToolbar.Identifier {
    static let toolbarIdentifier = NSToolbar.Identifier("MainWindowToolbarIdentifier")
}
fileprivate extension NSToolbarItem.Identifier {
    static let open = NSToolbarItem.Identifier(rawValue: "openToolbarItemIdentifier")
    static let save = NSToolbarItem.Identifier(rawValue: "saveToolbarItemIdentifier")
    static let undo = NSToolbarItem.Identifier(rawValue: "undoToolbarItemIdentifier")
    static let redo = NSToolbarItem.Identifier(rawValue: "redoToolbarItemIdentifier")
    static let cut = NSToolbarItem.Identifier(rawValue: "cutToolbarItemIdentifier")
    static let copy = NSToolbarItem.Identifier(rawValue: "copyToolbarItemIdentifier")
    static let paste = NSToolbarItem.Identifier(rawValue: "pasteToolbarItemIdentifier")
    static let delete = NSToolbarItem.Identifier(rawValue: "deleteToolbarItemIdentifier")
}
fileprivate extension NSColor {
    static var windowBackgroundColor: NSColor {
        NSColor(red: 39.0/255.0, green: 42.0/255.0, blue: 54.0/255.0, alpha: 1.0)
    }
}
fileprivate extension NSImage.Name {
    static let open = NSImage.Name("folder")
    static let save = NSImage.Name("square.and.arrow.up")
    static let undo = NSImage.Name("arrow.uturn.backward")
    static let redo = NSImage.Name("arrow.uturn.forward")
    static let cut = NSImage.Name("scissors")
    static let copy = NSImage.Name("doc.on.clipboard")
    static let paste = NSImage.Name("doc.on.doc")
    static let delete = NSImage.Name("trash")
}
fileprivate extension NSPasteboard.PasteboardType {
    static let audio = NSPasteboard.PasteboardType("com.russelldzhafarov.audio-editor-macos.audio.pbtype")
}

class WindowController: NSWindowController {

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
        
        window?.toolbar?.validateVisibleItems()
        window?.backgroundColor = NSColor.windowBackgroundColor
    }
    
    // MARK: - Toolbar Item Custom Actions
    @IBAction func open(_ sender: Any) {
    }
    @IBAction func save(_ sender: Any) {
    }
    @IBAction func undo(_ sender: Any) {
        undoManager?.undo()
    }
    @IBAction func redo(_ sender: Any) {
        undoManager?.redo()
    }
    @IBAction func cut(_ sender: Any) {
    }
    @IBAction func copy(_ sender: Any) {
    }
    @IBAction func paste(_ sender: Any) {
    }
    @IBAction func delete(_ sender: Any) {
    }
}

extension WindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        true
    }
}

extension WindowController: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .open:
            return true
        case .save:
            return window?.undoManager?.canUndo ?? false
        case .undo:
            return window?.undoManager?.canUndo ?? false
        case .redo:
            return window?.undoManager?.canRedo ?? false
        case .cut:
            return false
        case .copy:
            return false
        case .paste:
            return NSPasteboard.general.data(forType: .audio)?.isEmpty == false
        case .delete:
            return false
        default:
            return false
        }
    }
}

extension WindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .open,
            .save,
            .space,
            .undo,
            .redo,
            .cut,
            .copy,
            .paste,
            .delete,
            .flexibleSpace
        ]
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .open,
            .save,
            .undo,
            .redo,
            .cut,
            .copy,
            .paste,
            .delete,
            .space,
            .flexibleSpace
        ]
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        
        let label: String
        let action: Selector
        let symbolName: String
        switch itemIdentifier {
        case .open:
            label = "Open"
            action = #selector(open(_:))
            symbolName = .open
            
        case .save:
            label = "Save"
            action = #selector(save(_:))
            symbolName = .save
            
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
