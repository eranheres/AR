//
//  ARObject.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 25/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit
import ARKit
import UIKit

struct CamObject : Codable {
    let player : String
    let pos : [Float]
    let dir : [Float]
    let ang : [Float]

    init (player: String, pos: SCNVector3, dir: SCNVector3, angle: SCNVector3) {
        self.player = player
        self.pos = [pos.x, pos.y, pos.z]
        self.dir = [dir.x, dir.y, dir.z]
        self.ang = [angle.x, angle.y, angle.z]

    }
    var position: SCNVector3! { return SCNVector3(pos[0], pos[1], pos[2]) }
    var direction: SCNVector3! { return SCNVector3(dir[0], dir[1], dir[2]) }
    var angle: SCNVector3! { return SCNVector3(ang[0], ang[1], ang[2]) }
}


/// Helpers
