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
        
        if clnt.isInLobby && !clnt.isInGameRoom {
            netLogic.createRoom()
        }
        netLogic.service()
    }
    
    func sendWorldAlignmentMessage(coodrdinates: SCNMatrix4) {
        netAppLayer?.sendWorldAlignmentMessage(coordinates: matrix4toArray(matrix: coodrdinates))
    }
    
    func receiveWorldAlignmentMessage(_ coordinates: [Float]) {
        allignWorldToCoordinator(transform: array2matrix4(coordinates))
    }
    
    func receiveObjectsLocationMessage(_ arObjects: [ARObject]) {
        let existingNodes = sceneView.scene.rootNode.childNodes
        
        for obj in arObjects {
            let matrix4 = array2matrix4(obj.matrix)
            if let node = existingNodes.first(where: { $0.name == obj.uuid }) {
                node.transform = matrix4
            } else {
                addBoxOnTransform(id: obj.uuid, transform: matrix4)
            }
        }
    }
    
    func array2matrix4(_ array: [Float]) -> SCNMatrix4 {
        let a = array
        return SCNMatrix4(m11: a[0], m12: a[1], m13: a[2],  m14:a[3],
                          m21: a[4], m22: a[5], m23: a[6],  m24:a[7],
                          m31: a[8], m32: a[9], m33: a[10], m34:a[11],
                          m41: a[12],m42: a[13],m43: a[14], m44:a[15])
    }
    
    func matrix4toArray(matrix : SCNMatrix4) -> [Float] {
        let m = matrix
        return [m.m11, m.m12, m.m13, m.m14,
                m.m21, m.m22, m.m23, m.m24,
                m.m31, m.m32, m.m33, m.m34,
                m.m41, m.m42, m.m43, m.m44]

    }
    
    @objc func broadcastObjectsLocation() {
//        guard let nodes = sceneView.scene.rootNode.childNodes.first(where: { $0.name == "ARNode" })?.childNodes else { return }
        let nodes = sceneView.scene.rootNode.childNodes
        var list : [ARObject] = []
        for node in nodes {
            guard let uuid = node.name else { continue }
            let arObj = ARObject(uuid: uuid, matrix: matrix4toArray(matrix: node.transform))
            list.append(arObj)
        }
        
        netAppLayer?.sendObjectsLocationMessage(arObjects: list)
    }
    
}
