//
//  ViewController+NetworkDelegate.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 24/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation


extension ViewController: PhotonDelegateView {
        
    func log(_ s: String) {
        print(s)
    }
    
    func showState(_ state: Int, stateStr: String, roomName: String, playerNr: Int32, inLobby: Bool, inRoom: Bool) {
        var str = ""
        if (inRoom)
        {
            str = String("Network:"+String(format:"%@ room:%@ player#:%d", stateStr, roomName, playerNr))
        }
        else
        {
            str = String("Network:"+stateStr)
        }
        statusViewController.showMessage(str)
        log(str)
    }
    
    
}
