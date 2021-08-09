//
//  AppDelegate.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
