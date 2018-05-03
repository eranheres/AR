//
//  MPARNode.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 30/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit

struct MPARNodeCodable : Codable {
    let className : String
    let mparUuid : String
    let pos : [Float]
    var attributes :[String: String]?
    
    init (className: String, mparUuid: String, pos: SCNVector3) {
        self.mparUuid = mparUuid
        self.className = className
        self.pos = pos.array
        self.attributes = nil
    }
    var vector: SCNVector3 { return SCNVector3(pos[0], pos[1], pos[2]) }
}

class MPARNode : SCNNode {
    var mparUuid: String
    var slave : Bool = false
    var additionPropertiesHandler : (() -> Codable?)? = nil
    
    required override init() {
        self.mparUuid = ""
        super.init()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private class func stringClassFromString(_ className: String) -> AnyClass! {
        let namespace = Bundle.main.infoDictionary!["CFBundleExecutable"] as! String;
        let cls: AnyClass = NSClassFromString("\(namespace).\(className)")!;
        return cls;
    }
    
    class func newFrom(from nodeInfo: MPARNodeCodable) -> MPARNode? {
        var instance: AnyObject! = nil
        guard let clz = stringClassFromString(nodeInfo.className) as? MPARNode.Type else { return nil }
        instance = clz.init()
        guard let node = instance as? MPARNode else { return nil }
        node.slave = true
        node.initFromNodeInfo(from: nodeInfo)
        return node
    }

    func codable() -> MPARNodeCodable? {
        let clz = NSStringFromClass(type(of: self)).components(separatedBy: ".").last!
        let ret = MPARNodeCodable(className: clz, mparUuid: mparUuid, pos: self.transform.vector)
        return ret
    }
    
    func initFromNodeInfo(from nodeInfo: MPARNodeCodable) {
        mparUuid = nodeInfo.mparUuid
        self.transform = SCNMatrix4MakeTranslation(nodeInfo.vector.x, nodeInfo.vector.y, nodeInfo.vector.z)
        
        // box.materials = boxColor()
        // boxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        // boxNode.physicsBody?.isAffectedByGravity = false
    }
    
    func applyChanges(from: MPARNodeCodable) {
        let action = SCNAction.move(to: from.vector, duration: 0.1)
        self.runAction(action)
    }
}
