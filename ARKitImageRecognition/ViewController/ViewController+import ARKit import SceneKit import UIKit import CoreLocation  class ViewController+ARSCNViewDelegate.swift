//
//  ViewController+import ARKit import SceneKit import UIKit import CoreLocation  class ViewController+ARSCNViewDelegate.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 29/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation

import ARKit
import SceneKit
import UIKit
import CoreLocation

extension ViewController: ARSCNViewDelegate {

    func renderDetectedImage(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for imageAnchor: ARImageAnchor) {
        let referenceImage = imageAnchor.referenceImage
        
        updateQueue.async {
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.4
            planeNode.eulerAngles.x = -.pi / 2
            planeNode.runAction(self.imageHighlightAction)
            node.addChildNode(planeNode)
        }

        updateQueue.async {
            let box = SCNBox(width: referenceImage.physicalSize.width,
                             height: referenceImage.physicalSize.height,
                             length: 0.01,
                             chamferRadius: 0)
            let boxNode = SCNNode(geometry: box)
            boxNode.eulerAngles.x = -.pi / 2
            // Add the plane visualization to the scene.
            node.addChildNode(boxNode)
        }
        /*
         DispatchQueue.main.async {
         let imageName = referenceImage.name ?? ""
         self.statusViewController.cancelAllScheduledMessages()
         self.statusViewController.showMessage("Detected image “\(imageName)”")
         }
         */
    }
    
    func renderPlane(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for planeAnchor: ARPlaneAnchor) {
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        //let plane = SCNBox(width: width, height: height, length: 0.001, chamferRadius: 0)
        let plane = SCNPlane(width: width, height: height)

        plane.materials.first?.diffuse.contents = UIColor.lightGray
        plane.materials.first?.transparency = 0.15
        let planeNode = SCNNode(geometry: plane)
        planeNode.name = "plane"
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2
        
//      planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
//      planeNode.physicsBody?.isAffectedByGravity = false
//      planeNode.physicsBody?.resetTransform()

        
        node.addChildNode(planeNode)
    }
    
    func updatePlane(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for planeAnchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x, y, z)
        guard let planePhysics = planeNode.physicsBody else { return }
        planePhysics.resetTransform()
        /*
        while (true) {
            let collisions = sceneView.scene.physicsWorld.contactTest(with: planePhysics)
            if (collisions.count == 0) {
                break
            }
            
            collisions.forEach{ collision in
                let node = collision.nodeB
                guard let n = node.name?.prefix(4) else { return }
                if (n == String("obj-")) {
                    print("found collision")
                    var translation = matrix_identity_float4x4
                    translation.columns.3.y = 0.1
                    let transform = simd_mul(simd_float4x4(node.transform),translation)
                    node.transform = SCNMatrix4(transform)
                    node.physicsBody?.resetTransform()
                }
                
            }
        }
        */
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            renderDetectedImage(renderer, didAdd: node, for: imageAnchor)
        }
        if let planeAnchor = anchor as? ARPlaneAnchor {
            renderPlane(renderer, didAdd: node, for: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor else { return }
        updatePlane(renderer, didUpdate: node, for: planeAnchor)
    }

}
