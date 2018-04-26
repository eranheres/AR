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

struct ARObject : Codable {
    let uuid : String
    let vect : [Float]
    init (uuid: String, vector: SCNVector3) {
        self.uuid = uuid
        self.vect = [vector.x, vector.y, vector.z]
    }
    var vector: SCNVector3 { return SCNVector3(vect[0], vect[1], vect[2]) }
}

extension SCNVector3 {
    var transform : SCNMatrix4 { return SCNMatrix4MakeTranslation(x,y,z) }
    var array : [Float] { return [x,y,z] }
}
extension SCNMatrix4 {
    var vector : SCNVector3 { return SCNVector3(m41,m42,m43) }
}
