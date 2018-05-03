//
//  MPAREngine + HandshakeDelegate.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 30/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation

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
import AudioToolbox

extension MPAREngine:  HandshakeSequenceDelegate {
    
    func startHandshake() {
        //let transform = SCNMatrix4MakeRotation(3.14159, 0.0,1.0,0.0)
        self.handshakeSequence?.start()
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func handshakeSuccess() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func handshakeApplyCameraInfo(camera: CamObject) {
        guard let heading = self.trueHeading() else { return }
        self.handshakeSequence?.feedCoordinates(
            masterCamera:camera,
            masterRealHeading:heading)   // TODO - fix with actual slave heading info
    }
    
    func realHeadingDelegate() -> CLHeading? {
        return trueHeading()
    }

    
    func worldAlignmentCallback(_ relativeTransform: SCNMatrix4) {
        session?.setWorldOrigin(relativeTransform: float4x4.init(relativeTransform))
    }
    
    func camVectorsDelegate() -> CamObject? {
        return self.getCameraVectors()
    }
}
