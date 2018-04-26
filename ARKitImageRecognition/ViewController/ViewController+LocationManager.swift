//
//  ViewController+LocationManager.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 26/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

extension CGFloat {
    var degreesToRadians: CGFloat { return self * .pi / 180 }
    var radiansToDegrees: CGFloat { return self * 180 / .pi }
}

private extension Double {
    var degreesToRadians: Double { return Double(CGFloat(self).degreesToRadians) }
    var radiansToDegrees: Double { return Double(CGFloat(self).radiansToDegrees) }
}

extension ViewController:  CLLocationManagerDelegate {
    
    func initLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        trueHeading = newHeading.trueHeading
        let heading = newHeading.trueHeading
        let accuracy = newHeading.headingAccuracy
        print("accuracy:\(accuracy) heading:\(heading);\(heading.degreesToRadians)")
        // self.statusViewController.showMessage("North: acc:\(accuracy) heading:\(heading)")
    }
}
