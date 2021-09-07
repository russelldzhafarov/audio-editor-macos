//
//  TimeInterval.swift
//  Audio Editor
//
//  Created by russell.dzhafarov@gmail.com on 06.09.2021.
//

import Foundation

extension TimeInterval {
    func mmss() -> String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        
        return String(format: "%0d:%02d", m, s)
    }
    
    func mmssms() -> String {
        let m = Int(self) / 60
        let s = Int(self) % 60
        let ms = Int((truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%0d:%02d,%02d", m, s, ms/10)
    }
    
    func hhmmssms() -> String {
        let h = Int(self / 3600)
        let m = Int(self) / 60
        let s = Int(self) % 60
        let ms = Int((truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d.%02d", h, m, s, ms)
    }
}
