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
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(ViewController.broadcastObjectsLocation), userInfo: nil, repeats: true)

        networkLogic?.updateState()
    }
    
    @objc func service()
    {
        guard let netLogic = networkLogic else {return}
        guard let clnt = netLogic.client else {return}
        let validStates :[Int32] = [2, 3, 4, 5, 6, 8, 10, 11, 12, 13, 14, 15, 16]
        if clnt.isInLobby && !clnt.isInGameRoom {
            netLogic.createRoom()
        } else if (clnt.state == 1) {   // PeerCreated
            netLogic.connect()
        } else if (!validStates.contains(clnt.state)) {
            print("Photon: unknown state")
        }
        if (clnt.state == 15) { // Connected
            statusViewController.errorHandler?.reportOK(module: .connection)
        } else {
            statusViewController.errorHandler?.reportError(module: .connection, str: "Connection not ready:"+PeerStatesStr[Int(clnt.state)])
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
    
    func sendCameraMessage(camera: CamObject) {
        netAppLayer?.sendCameraMessage(camera: camera)
    }
    
    func receiveCameraMessage(_ camera: CamObject) {
        let existingNodes = sceneView.scene.rootNode.childNodes
        let camPos = camera.position
        if let node = existingNodes.first(where: { $0.name == camera.player }) {
            let moveTo = SCNAction.move(to: camPos, duration: 0.1)
            node.runAction(moveTo)
        } else {
            _ = addBoxOnTransform(id: camera.player, transform: camPos.transform)
        }
        self.handshakeApplyCameraInfo(camera: camera)
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
