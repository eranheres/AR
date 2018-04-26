//
//  MessagesHandler.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 25/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit

protocol NetworkApplicationLayerDelegate {
    func receiveWorldAlignmentMessage(_ coordinates: [Float])
    func receiveObjectsLocationMessage(_ arObjects: [ARObject])
}

class NetworkApplicationLayer {
    
    enum MSGID : UInt8 {
        case worldAlignment=0, objectsLocation=1
    }
    
    var transportLayer : NetworkTransportLayerProtocol?
    var delegate : NetworkApplicationLayerDelegate?
    
    init(delegate: NetworkApplicationLayerDelegate) {
        self.delegate = delegate
    }
        
    func sendWorldAlignmentMessage(coordinates: [Float]) {
        guard let jsonData = try? JSONEncoder().encode(coordinates) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        transportLayer?.sendMessage(messageId: MSGID.worldAlignment.rawValue, message: jsonString)
    }
    
    func sendObjectsLocationMessage(arObjects: [ARObject]) {
        guard let jsonData = try? JSONEncoder().encode(arObjects) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        let messageId = MSGID.objectsLocation.rawValue
        transportLayer?.sendMessage(messageId: messageId, message: jsonString)
    }
    
    private func handleWorldAlignmentMessage(str : String) {
        guard let objects = try? JSONDecoder().decode([Float].self, from: str.data(using: .utf8)!) else { return }
        delegate?.receiveWorldAlignmentMessage(objects)
    }
    
    private func handleObjectsLocationMessage(str: String) {
        guard let objects = try? JSONDecoder().decode([ARObject].self, from: str.data(using: .utf8)!) else { return }
        delegate?.receiveObjectsLocationMessage(objects)
    }
    
    
    func handleRx(msgId : UInt8, str : String) {
        guard let msg = MSGID(rawValue: msgId) else {return}
        switch (msg) {
            case .worldAlignment: handleWorldAlignmentMessage(str: str)
            case .objectsLocation: handleObjectsLocationMessage(str: str)
        }
    }
}
