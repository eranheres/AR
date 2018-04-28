//
//  ViewController+HandshakeSequence.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 27/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit
import CoreLocation

extension ViewController:  HandshakeSequenceDelegate {
    
    func startHandshake() {
        //let transform = SCNMatrix4MakeRotation(3.14159, 0.0,1.0,0.0)
        self.handshakeSequence?.start()
    }
    
    func handshakeApplyCameraInfo(camera: CamObject) {
        guard let heading = self.trueHeading else { return }
        self.handshakeSequence?.feedCoordinates(
            masterCamera:camera,
            masterRealHeading:heading)   // TODO - fix with actual slave heading info
    }
    
    func worldAlignmentCallback(_ relativeTransform: SCNMatrix4) {
        session.setWorldOrigin(relativeTransform: float4x4.init(relativeTransform))
    }
    
    func realHeadingDelegate() -> CLHeading? {
        return trueHeading
    }
    
    func camVectorsDelegate() -> CamObject? {
        return self.getCameraVectors()
    }
}
