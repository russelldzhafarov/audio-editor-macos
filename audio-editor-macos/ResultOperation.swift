//
//  ResultOperation.swift
//  audio-editor-macos
//
//  Created by russell.dzhafarov@gmail.com on 16.08.2021.
//

import Foundation

class ResultOperation<T>: Operation {
    var result: Result<T, Error>!
}

class GroupOperation<T>: ResultOperation<T> {
    let queue = OperationQueue()
    var operations: [Operation] = []
    
    override func main() {
        queue.addOperations(operations, waitUntilFinished: true)
    }
}
