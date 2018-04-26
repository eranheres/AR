//
//  ViewController+NetworkDelegate.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 25/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//
import ARKit
import SceneKit
import UIKit


extension ViewController: NetworkApplicationLayerDelegate {
    
    func startNetwork() {
        // Start network
        self.netAppLayer = NetworkApplicationLayer(delegate: self)
        networkLogic = NetworkLogic(demoView : self, networkApplicationLayer: netAppLayer!)
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.service), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(ViewController.broadcastObjectsLocation), userInfo: nil, repeats: true)

        networkLogic?.updateState()
    }
    
    @objc func service()
    {
        guard let netLogic = networkLogic else {return}
        guard let clnt = netLogic.client else {return}
        
        if clnt.isInLobby && !clnt.isInGameRoom {
            netLogic.createRoom()
        }
        netLogic.service()
    }
    
    //////    World alignment
    
    func sendWorldAlignmentMessage(vector: SCNVector3) {
        netAppLayer?.sendWorldAlignmentMessage(vector: vector)
    }
    
    func receiveWorldAlignmentMessage(_ vector: SCNVector3) {
        alignWorldToCoordinator(vector: vector)
    }

    //////    Camera location
    
    func sendCameraMessage(camera: ARObject) {
        netAppLayer?.sendCameraMessage(camera: camera)
    }
    
    func receiveCameraMessage(_ camera: ARObject) {
        let existingNodes = sceneView.scene.rootNode.childNodes
        let vec = camera.vector
        if let node = existingNodes.first(where: { $0.name == camera.uuid }) {
            let moveTo = SCNAction.move(to: vec, duration: 0.1)
            node.runAction(moveTo)
        } else {
            _ = addBoxOnTransform(id: camera.uuid, transform: vec.transform)
        }
    }

    
    //////    Object location

    func receiveObjectsLocationMessage(_ arObjects: [ARObject]) {
        let existingNodes = sceneView.scene.rootNode.childNodes
        
        for obj in arObjects {
            let vec = obj.vector
            if let node = existingNodes.first(where: { $0.name == obj.uuid }) {
                let moveTo = SCNAction.move(to: vec, duration: 0.1)
                node.runAction(moveTo)
            } else {
                _ = addBoxOnTransform(id: obj.uuid, transform: vec.transform)
            }
        }
    }

    @objc func broadcastObjectsLocation() {
        let nodes = sceneView.scene.rootNode.childNodes
        var list : [ARObject] = []
        for node in nodes {
            guard let uuid = node.name else { continue }
            if uuid.prefix(4) == String("obj-") {
                let arObj = ARObject(uuid: uuid, vector: node.transform.vector)
                list.append(arObj)
            }
        }
        
        netAppLayer?.sendObjectsLocationMessage(arObjects: list)
    }
    
}
