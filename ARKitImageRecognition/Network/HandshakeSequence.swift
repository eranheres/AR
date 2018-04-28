//
//  HandshakeSequence.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 27/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import SceneKit
import CoreLocation

protocol HandshakeSequenceDelegate {
    // Handler to set world alignment with offset coordinates
    func worldAlignmentCallback(_ relativeTransform: SCNMatrix4) -> Void
    
    // Delegates to get the device info
    func realHeadingDelegate () -> CLHeading?
    func camVectorsDelegate () -> CamObject?   
}

class HandshakeSequence {
    var isDuringSequence : Bool = false
    private var verifiedSamplesCount = 0
    private var startSequenceTime : Date = Date()
    
    private let delegate : HandshakeSequenceDelegate
    
    private let CAMERA_POSITION_ALIGN_THRESHOLD = Float(0.3)
    private let CAMERA_ANGLE_ALIGN_DEGREE_THRESHOLD = CGFloat(1.0)
    private let READ_HEADING_ALIGN_THRESHOLD = Float(0.001)

    init(delegate: HandshakeSequenceDelegate) {
        self.delegate = delegate
    }

    func start() {
        if isDuringSequence { return }
        verifiedSamplesCount = 0
        isDuringSequence = true
        startSequenceTime = Date()
    }
    
    func stop() {
        if !isDuringSequence { return }
        isDuringSequence = false
    }
    
    func feedCoordinates(masterCamera: CamObject,
                         masterRealHeading: CLHeading) {
        if !isDuringSequence { return }
        guard let slaveCamera = delegate.camVectorsDelegate() else { return }
        guard let slaveRealHeading = delegate.realHeadingDelegate() else { return }
        
        if (verifySample(slaveCamera: slaveCamera,
                         slaveRealHeading: slaveRealHeading,
                         masterCamera: masterCamera,
                         masterRealHeading: masterRealHeading)) {
            
        }
    }
    
    func verifySample(slaveCamera: CamObject,
                      slaveRealHeading: CLHeading,
                      masterCamera: CamObject,
                      masterRealHeading: CLHeading) -> Bool {
        let camPosDistance = (slaveCamera.position - masterCamera.position).rsqrt()
         let camAngleDiff = (slaveCamera.angle.y) + Float(CGFloat.pi) - (masterCamera.angle.y)
        let headingDiff = Float(slaveRealHeading.trueHeading - masterRealHeading.trueHeading)
        let headingDistance = sqrtf(headingDiff*headingDiff)
        
        if (slaveRealHeading.headingAccuracy > 40 || masterRealHeading.headingAccuracy > 40 ||
            slaveRealHeading.headingAccuracy == -1 || masterRealHeading.headingAccuracy == -1) {
            print("Handshake: Heading accuracy too low [slave:\(slaveRealHeading.headingAccuracy),master\(masterRealHeading.headingAccuracy)]")
            verifiedSamplesCount = 0
            return false
        }
        
        if (headingDistance > READ_HEADING_ALIGN_THRESHOLD) {
            
            print("Handshake: RealHeading too high [\(headingDistance)]")
            verifiedSamplesCount = 0
            return false
        }
        print("Handshake: RealHeading OK [\(headingDistance)]")
        

        if (abs(CGFloat(camAngleDiff).radiansToDegrees.truncatingRemainder(dividingBy: 360)) > CAMERA_ANGLE_ALIGN_DEGREE_THRESHOLD) {
            print(String(format:"Handshake: Angle too high [diff:%.3f(%.3f)] [master:%.3f] [slave:%.3f] ",
                  camAngleDiff, CGFloat(camAngleDiff).radiansToDegrees,
                  masterCamera.angle.y, slaveCamera.angle.y))
            alignWorldDirection(camAngleDiff)
            verifiedSamplesCount = 0
            return false
        }
        print("Handshake: Angle OK [\(camAngleDiff)]")


        if (camPosDistance > CAMERA_POSITION_ALIGN_THRESHOLD) {
            print("Handshake: CameraPosDistance too high [\(camPosDistance)]")
            let transform = SCNMatrix4MakeTranslation(
                slaveCamera.position.x - masterCamera.position.x,
                slaveCamera.position.y - masterCamera.position.y,
                slaveCamera.position.z - masterCamera.position.z)
            delegate.worldAlignmentCallback(transform)
            verifiedSamplesCount = 0
            return false
        }
        print("Handshake: CameraPosDistance OK [\(camPosDistance)]")
        
        verifiedSamplesCount = verifiedSamplesCount + 1
        print("Verified sample \(verifiedSamplesCount)")
        if verifiedSamplesCount >= 5 {
            stop()
            // let transform = SCNMatrix4MakeRotation(Float(CGFloat.pi/2), 0.0,1.0,0.0)
            // delegate.worldAlignmentCallback(transform)
        }
        return true
    }
    
    func alignWorldDirection(_ angle : Float) {
//      let angle = atan2(slaveDir.x - masterDir.x, slaveDir.z - masterDir.z)
        print("currenting angle by:\(CGFloat(angle).radiansToDegrees)")
        let transform = SCNMatrix4MakeRotation(angle, 0.0,1.0,0.0)
        delegate.worldAlignmentCallback(transform)
  //      SCNMatrix4MakeRotation(<#T##angle: Float##Float#>, <#T##x: Float##Float#>, <#T##y: Float##Float#>, <#T##z: Float##Float#>)
    }
}

extension SCNVector3 {
    func rsqrt() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}
func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)
}
prefix func - (l: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(-l.x,-l.y,-l.z)
}

