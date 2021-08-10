//
//  ViewModel.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 10.08.2021.
//

import Foundation
import Combine

class ViewModel: ObservableObject {
    
    @Published public var selectedTimeRange: Range<TimeInterval> = 0.0 ..< 0.0
    @Published public var visibleTimeRange: Range<TimeInterval> = 0.0 ..< 60.0
    @Published public var currentTime: TimeInterval = 0.0
    
    @Published public var highlighted = false
}
