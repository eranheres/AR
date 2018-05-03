//
//  Shoot.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 30/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit

class Shoot : MPARNode {
    var scene : SCNScene?
    var from : SCNVector3? = nil
    var to : SCNVector3? = nil
    
    required init() {
        super.init()
        self.mparUuid = "shoot-"+UUID().uuidString
    }
    
    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    override func initFromNodeInfo(from nodeInfo: MPARNodeCodable) {
        super.initFromNodeInfo(from: nodeInfo)
        guard let attr = nodeInfo.attributes else { fatalError("Got shoot object without attributes") }
        guard let fromStr = attr["from"] else { fatalError("Didn't get the 'from' value from attribute list") }
        guard let toStr = attr["to"] else { fatalError("Didn't get the 'to' value from attribute list") }
        placeShoot(from: SCNVector3(fromStr), to: SCNVector3(toStr))
    }
    
    override func codable() -> MPARNodeCodable? {
        var ret = super.codable()
        if let f = from?.str {
            if let t = to?.str {
                ret?.attributes = ["from":f, "to":t]
            }
        }
        return ret
    }

    func start(camera: CamObject, hitWorldCoordinates hit: SCNVector3?) {
        var endPoint : SCNVector3?
        
        guard let startPoint = camera.position else { return }
        
        if hit != nil {
            endPoint = hit
        } else {
            guard let dir = camera.direction else { return }
            let translate = SCNMatrix4MakeTranslation(dir.x, dir.y, dir.z)
            let transform = simd_mul(matrix_float4x4(camera.position.transform), matrix_float4x4(translate))
            endPoint = SCNMatrix4(transform).vector
        }
        from = startPoint
        to = endPoint
        placeShoot(from: startPoint, to: endPoint!)
    }
    
    func placeShoot(from: SCNVector3, to: SCNVector3) {
        _ = buildLineInTwoPointsWithRotation(
            from: from,
            to: to,
            radius: 0.001,
            color:UIColor.cyan)
        scene?.rootNode.addChildNode(self)
        
        Timer.scheduledTimer(
            withTimeInterval:0.4,
            repeats: false,
            block: {_ in
                self.removeFromParentNode()
        } )
    }
    
}
