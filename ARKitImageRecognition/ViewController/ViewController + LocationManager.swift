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

extension ViewController:  CLLocationManagerDelegate {
 
    func initLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        trueHeading = newHeading
        let heading = newHeading.trueHeading
        let accuracy = newHeading.headingAccuracy
        if (accuracy > 45) {
            let str = ("bad north accuracy:\(accuracy) heading:\(heading);\(CGFloat(heading).degreesToRadians)")
            self.statusViewController.errorHandler?.reportError(module: .heading, str: str)
        } else {
            self.statusViewController.errorHandler?.reportOK(module: .heading)
        }
    }
}


