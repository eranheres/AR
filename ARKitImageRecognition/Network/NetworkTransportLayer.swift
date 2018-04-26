//
//  NetworkTransportLayer.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 25/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation

protocol NetworkTransportLayerDelegate {
    func handleRx(messageId: UInt8, message: String)
}

protocol NetworkTransportLayerProtocol {
    func sendMessage(messageId: UInt8, message: String)
}
