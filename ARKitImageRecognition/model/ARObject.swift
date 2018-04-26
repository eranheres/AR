//
//  ARObject.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 25/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit

struct ARObject : Codable {
    let uuid : String
    let matrix : [Float]
    
    init (uuid: String, matrix: [Float]) {
        self.uuid = uuid
        self.matrix = matrix
    }

}
