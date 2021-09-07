//
//  AppDelegate.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 09.08.2021.
//

import Cocoa
import AVFoundation
import Accelerate

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return false
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
    func applicationWillTerminate(_ notification: Notification) {
        if NSPasteboard.general.data(forType: AVAudioPCMBuffer.pbType)?.isEmpty == false {
            NSPasteboard.general.clearContents()
        }
    }
}
