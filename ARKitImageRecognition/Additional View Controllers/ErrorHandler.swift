//
//  ErrorHandler.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 28/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation

class ErrorHandler {
    
    var showMessageDelegate : (_ : String) -> Void
    var statusOkSent : Bool = true

    
    init(delegate: @escaping (_: String)->Void) {
        showMessageDelegate = delegate
    }
    
    enum Module: Int {
        case ar=0, connection=1, heading=2
    }
    
    var errorStrings : [String] = ["", "", ""]
    
    func reportError(module: Module, str: String) {
        var statusChanged : Bool = false
        switch module {
            case .ar: statusChanged = (errorStrings[Module.ar.rawValue] != str)
            case .connection: statusChanged = ( errorStrings[Module.connection.rawValue] != str)
            case .heading: statusChanged = (errorStrings[Module.heading.rawValue] != str)
        }
        if (!statusChanged) {
            return
        }
        
        switch module {
            case .ar: errorStrings[Module.ar.rawValue] = str
            case .connection: errorStrings[Module.connection.rawValue] = str
            case .heading: errorStrings[Module.heading.rawValue] = str
        }
        refreshStatus()
    }
    
    func reportOK(module: Module) {
        reportError(module: module, str: "")
    }
    
    func refreshStatus() {
        let s = errorStrings.filter{ $0 != "" }.joined(separator: "\n")
        if s != "" {
            showMessageDelegate(s)
            statusOkSent = false
        }
        else if (!statusOkSent) {
            statusOkSent = true
            showMessageDelegate("Status is OK!")
        }
    }
}
