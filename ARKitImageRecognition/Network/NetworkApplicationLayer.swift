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
    func receiveWorldAlignmentMessage(_ vector: SCNVector3)
    func receiveObjectsLocationMessage(_ arObjects: [ARObject])
    func receiveCameraMessage(_ arObjects: ARObject)
}

class NetworkApplicationLayer {
    
    enum MSGID : UInt8 {
        case worldAlignment=0, objectsLocation=1, camera=2
    }
    
    var transportLayer : NetworkTransportLayerProtocol?
    var delegate : NetworkApplicationLayerDelegate?
    
    init(delegate: NetworkApplicationLayerDelegate) {
        self.delegate = delegate
    }
        
    func sendWorldAlignmentMessage(vector: SCNVector3) {
        guard let jsonData = try? JSONEncoder().encode(vector.array) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        transportLayer?.sendMessage(messageId: MSGID.worldAlignment.rawValue, message: jsonString)
    }
    
    func sendObjectsLocationMessage(arObjects: [ARObject]) {
        guard let jsonData = try? JSONEncoder().encode(arObjects) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        let messageId = MSGID.objectsLocation.rawValue
        transportLayer?.sendMessage(messageId: messageId, message: jsonString)
    }

    func sendCameraMessage(camera: ARObject) {
        guard let jsonData = try? JSONEncoder().encode(camera) else { return }
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        let messageId = MSGID.camera.rawValue
        transportLayer?.sendMessage(messageId: messageId, message: jsonString)
    }
    
    private func handleWorldAlignmentMessage(str : String) {
        guard let arr = try? JSONDecoder().decode([Float].self, from: str.data(using: .utf8)!) else { return }
        delegate?.receiveWorldAlignmentMessage(SCNVector3(arr[0],arr[1],arr[2]))
    }
    
    private func handleObjectsLocationMessage(str: String) {
        guard let objects = try? JSONDecoder().decode([ARObject].self, from: str.data(using: .utf8)!) else { return }
        delegate?.receiveObjectsLocationMessage(objects)
    }

    private func handleCameraMessage(str: String) {
        guard let camera = try? JSONDecoder().decode(ARObject.self, from: str.data(using: .utf8)!) else { return }
        delegate?.receiveCameraMessage(camera)
    }

    
    func handleRx(msgId : UInt8, str : String) {
        guard let msg = MSGID(rawValue: msgId) else {return}
        switch (msg) {
            case .worldAlignment: handleWorldAlignmentMessage(str: str)
            case .objectsLocation: handleObjectsLocationMessage(str: str)
            case .camera: handleCameraMessage(str: str)
        }
    }
}
