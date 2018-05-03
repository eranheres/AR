//
//  Jumper.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 29/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit

class Jumper : MPARNode {
    
    var scene : SCNScene?
    var maxJumpDistanceX : Float = 1.0
    var maxJumpDistanceY : Float = 1.0
    var maxJumpDistanceZ : Float = 1.0
    
    var maxTimeBetweenJumps : UInt32 = 10
    var minTimeBetweenJumps : UInt32 = 4
    
    var jumpTimer : Timer?

    required init() {
        super.init()
        mparUuid = "jumper-"+UUID().uuidString
    }

    required init(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    override func initFromNodeInfo(from nodeInfo: MPARNodeCodable) {
        super.initFromNodeInfo(from: nodeInfo)
        start(pos:nodeInfo.vector)
    }
    
    func start(pos : SCNVector3) {
        let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
        box.materials = boxColor()
        self.geometry = box
        self.position = pos
        scene?.rootNode.addChildNode(self)
        if !slave {
            runJumpTimer()
        }
            
        Timer.scheduledTimer(
            timeInterval:3.0,
            target: self,
            selector: #selector(Jumper.teeze),
            userInfo: nil,
            repeats: true)
    }
    
    @objc func runJumpTimer() {
        if let _ = jumpTimer {
            jumpToSpot(pos: findNextSpot())
        } else {
        }
        let nextTime = arc4random_uniform(maxTimeBetweenJumps-minTimeBetweenJumps)+minTimeBetweenJumps
        jumpTimer = Timer.scheduledTimer(
            timeInterval:Double(nextTime),
            target: self,
            selector: #selector(Jumper.runJumpTimer),
            userInfo: nil,
            repeats: false)
    }
    
    @objc func teeze() {
        let moveTo = SCNAction.rotateBy(x: CGFloat.pi, y: CGFloat.pi, z: CGFloat.pi, duration: 1)
        self.runAction(moveTo)
    }
    
    func jumpToSpot(pos : SCNVector3) {
        let moveTo = SCNAction.move(to: pos, duration: 1)
        print ("Jumper: moving to spot "+pos.str)
        self.runAction(moveTo)
    }
    
    func randomFloat() -> Float {
        return Float(Float(arc4random()) / Float(UINT32_MAX))
    }
    
    func getPalnes() -> [SCNNode] {
        let nodes = scene?.rootNode.childNodes
        let planes = nodes?.filter{ $0.childNodes.first?.name == "plane" }
        guard let p = planes else {
            return []
        }
        return p
    }
    
    func findNextSpot() -> SCNVector3 {
        let planes = getPalnes()
        let count = planes.count + 1
        let selection = arc4random_uniform(UInt32(count))   // +1 for air location
        if selection == 0 {
            while true {
                let newX = (randomFloat()*maxJumpDistanceX*2)-maxJumpDistanceX
                let newY = (randomFloat()*maxJumpDistanceY*2)-maxJumpDistanceY
                let newZ = (randomFloat()*maxJumpDistanceZ*2)-maxJumpDistanceZ
                let newPos = self.position + SCNVector3(newX, newY, newZ)
                if newPos.length < 3 && newPos.z > -1 {
                    return newPos
                }
            }
        } else {
            return planes[Int(selection - 1)].position
        }
    }
    
    func takeHit() {
        let moveTo = SCNAction.rotateBy(x: CGFloat.pi*2, y: CGFloat.pi*2, z: CGFloat.pi*2, duration: 0.5)
        self.runAction(moveTo)
        if !slave {
            let newPos = findNextSpot()
            jumpToSpot(pos: newPos)
        }
    }
    
    func boxColor() -> [SCNMaterial] {
        let colors = [UIColor.green, // front
            UIColor.red, // right
            UIColor.blue, // back
            UIColor.yellow, // left
            UIColor.purple, // top
            UIColor.gray] // bottom
        
        return colors.map { color -> SCNMaterial in
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.locksAmbientWithDiffuse = true
            return material
        }
    }
    
}
