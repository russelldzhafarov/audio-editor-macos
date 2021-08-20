//
//  NSColor.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import Cocoa

extension NSColor {
    static var windowBackgroundColor: NSColor {
        NSColor(red: 39.0/255.0, green: 42.0/255.0, blue: 54.0/255.0, alpha: 1.0)
    }
    static var waveformColor: NSColor {
        NSColor.systemTeal
    }
    static var waveformBackgroundColor: NSColor {
        NSColor(red: 30.0/255.0, green: 31.0/255.0, blue: 40.0/255.0, alpha: 1.0)
    }
    static var cursorColor: NSColor {
        NSColor.systemRed
    }
    static var selectionColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.3)
    }
    static var highlightColor: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.2)
    }
    static var rulerColor: NSColor {
        NSColor(red: 83.0/255.0, green: 89.0/255.0, blue: 105.0/255.0, alpha: 1.0)
    }
    static var rulerLabelColor: NSColor {
        NSColor(red: 142.0/255.0, green: 150.0/255.0, blue: 171.0/255.0, alpha: 1.0)
    }
}
