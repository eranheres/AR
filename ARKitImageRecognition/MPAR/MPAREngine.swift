//
//  MultiPlayerAR.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 30/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit
import CoreLocation
import ARKit
import UIKit


class MPAREngine : NetworkApplicationLayerDelegate, NetworkStateDelegate {
    
    var statusReportHandler : (_ isOk: Bool, _ status: String) -> Void = { a,b in }
    var sceneView : ARSCNView?
    
    private var networkLogic: NetworkLogic?
    private var netAppLayer: NetworkApplicationLayer?
    var handshakeSequence : HandshakeSequence?
    
    var trueHeading : () -> CLHeading? = { return nil }
    var session: ARSession? { return sceneView?.session }
    var scene: SCNScene? { return sceneView?.scene }
    
    var isDuringJoinSequence : Bool = false
    var player : String

    
    init () {
        player = "player-"+UUID().uuidString
        self.handshakeSequence = HandshakeSequence(delegate: self)
    }
    
    func start() {
        startNetwork()
    }
    
    func registerNode() {
    }
    
    func startNetwork() {
        // Start network
        self.netAppLayer = NetworkApplicationLayer(delegate: self)
        networkLogic = NetworkLogic(demoView : self, networkApplicationLayer: netAppLayer!)
        Timer.scheduledTimer(timeInterval: 0.03,
                             target: self,
                             selector: #selector(MPAREngine.service),
                             userInfo: nil,
                             repeats: true)
        Timer.scheduledTimer(timeInterval: 0.1,
                             target: self,
                             selector: #selector(MPAREngine.broadcastObjectsLocation),
                             userInfo: nil,
                             repeats: true)
        Timer.scheduledTimer(timeInterval:0.1,
                             target: self,
                             selector: #selector(MPAREngine.sendCameraPos),
                             userInfo: nil,
                             repeats: true)
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
            statusReportHandler(true, "OK")
        } else {
            statusReportHandler(false, "Connection not ready:"+PeerStatesStr[Int(clnt.state)])
        }
        netLogic.service()
    }
    
    //////    World alignment sequence
    
    
    func sendWorldAlignmentMessage(vector: SCNVector3) {
        //netAppLayer?.sendWorldAlignmentMessage(vector: vector)
    }
    
    func receiveWorldAlignmentMessage(_ vector: SCNVector3) {
        //alignWorldToCoordinates(vector: vector)
    }
    
    //////    Camera location
    
    func sendCameraMessage(camera: CamObject) {
        netAppLayer?.sendCameraMessage(camera: camera)
    }
    
    func receiveCameraMessage(_ camera: CamObject) {
        guard let existingNodes = scene?.rootNode.childNodes else { return }
        
        if let node = existingNodes.first(where: { $0.name == camera.player }) {
            updateCameraNode(camera: camera, node: node)
        } else {
            addCameraNode(camera)
        }
        handshakeApplyCameraInfo(camera: camera)
    }
    
    
    //////    Object location
    
    func receiveNodesMessage(_ nodesInfo: [MPARNodeCodable]) {
        guard let existingNodes = scene?.rootNode.childNodes else { return }
        let mparNodes = existingNodes.filter{ $0 is MPARNode }.map{ $0 as! MPARNode }
        
        for nodeInfo in nodesInfo {
            if let node = mparNodes.first(where: { $0.mparUuid == nodeInfo.mparUuid }) {
                node.applyChanges(from: nodeInfo)
            } else {
                guard let newNode = MPARNode.newFrom(from: nodeInfo) else {
                    fatalError("received un-known node of type "+nodeInfo.className)
                }
                sceneView?.scene.rootNode.addChildNode(newNode)
            }
        }
    }
    
    @objc func broadcastObjectsLocation() {
        guard let nodes = scene?.rootNode.childNodes else { return }
        let mparNodes = nodes
                            .filter{ $0 is MPARNode }.map{ $0 as! MPARNode }
                            .filter{ !$0.slave }
                            .map{ $0?.codable() }.filter{ $0 != nil }.map{ $0! }
        netAppLayer?.sendNodesMessage(arObjects: mparNodes)
    }
    
    ///// Camera vectors
    
    func getCameraVectors() -> CamObject? { // (direction, position)
        if let frame = session?.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            let eulerAngles = frame.camera.eulerAngles
            let angle = SCNVector3(eulerAngles.x, eulerAngles.y, eulerAngles.z)
            return CamObject(player:self.player, pos:pos, dir:dir, angle:angle)
        }
        return nil
    }
    
    // NetworkStateDelegate protocol
    
    func log(_ s: String) {
        print("Photon: "+s)
    }
    
    func showState(_ state: Int, stateStr: String, roomName: String, playerNr: Int32, inLobby: Bool, inRoom: Bool) {
        var str = ""
        if (inRoom)
        {
            str = String("Network:"+String(format:"%@ room:%@ player#:%d", stateStr, roomName, playerNr))
        }
        else
        {
            str = String("Network:"+stateStr)
        }
        log(str)
    }
    
    @objc func sendCameraPos() {
        guard let obj = self.getCameraVectors() else { return }
        netAppLayer?.sendCameraMessage(camera: obj)
        // print("\(camDir)")
    }
    
    func addCameraNode(_ camera: CamObject) {
        let node = SCNNode()
        let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
        node.geometry = box
        let colors = [UIColor.cyan, // front
            UIColor.purple, // right
            UIColor.cyan, // back
            UIColor.purple, // left
            UIColor.brown, // top
            UIColor.brown] // bottom
        let t = simd_mul(
        simd_mul(
        simd_float4x4(SCNMatrix4MakeRotation(camera.angle.x, 1, 0, 0)),
        simd_float4x4(SCNMatrix4MakeRotation(camera.angle.y, 0, 1, 0))),
        simd_float4x4(SCNMatrix4MakeRotation(camera.angle.z, 0, 0, 1)))
        node.transform = SCNMatrix4(t)
        box.materials = colors.map { color -> SCNMaterial in
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.locksAmbientWithDiffuse = true
            return material
        }
        node.name = camera.player
        scene?.rootNode.addChildNode(node)
    }

    func updateCameraNode(camera cam: CamObject, node: SCNNode) {
        let moveTo = SCNAction.move(to: cam.position, duration: 0.1)
        let rotateTo = SCNAction.rotateTo(
            x: CGFloat(cam.angle.x),
            y: CGFloat(cam.angle.y),
            z: CGFloat(cam.angle.z),
            duration: 0.1,
            usesShortestUnitArc: true)
        node.runAction(SCNAction.group([moveTo, rotateTo]))
    }
    
}
