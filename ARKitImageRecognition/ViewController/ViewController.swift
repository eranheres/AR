/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    private var posMessageTimer: Timer?
    var networkLogic: NetworkLogic?
    var netAppLayer: NetworkApplicationLayer?

    
    private var uiImage = UIImage(named:"iPhone X")
    //private var uiImageView : UIImageView?
    @IBOutlet var uiImageView: UIImageView!
    
    private var isDuringJoinSequence = false
    let locationManager = CLLocationManager()
    var trueHeading : CLLocationDirection?
    let playerName = UUID().uuidString
    
    /// The view controller that displays the status and "restart experience" UI.
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.flatMap({ $0 as? StatusViewController }).first!
    }()
    
    /// A serial queue for thread safety when modifying the SceneKit node graph.
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".serialSceneKitQueue")
    
    /// Convenience accessor for the session owned by ARSCNView.
    var session: ARSession {
        return sceneView.session
    }
    
    // MARK: - View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        statusViewController.joinHandler = { [unowned self] in
            self.startJoinSequence()
        }
        // Add tap gesture
        addTapGestureToSceneView()
        // Start network
        startNetwork()
        // Start location
        initLocationManager()
        
    }
    
    func loadImage() {
        uiImageView?.isUserInteractionEnabled = true
        uiImageView.image = uiImage
        uiImageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.didTapImage)))
        guard let imgView = uiImageView else { return }
        self.view?.addSubview(imgView)
    }
    
    func removeImage() {
        guard let imgView = uiImageView else { return }
        imgView.removeFromSuperview()
    }
    
    @objc func didTapImage() {
        stopJoinSequence()
    }
    
    func stopJoinSequence() {
        if !isDuringJoinSequence {
            return
        }
        removeImage()
        isDuringJoinSequence = false
    }
    
    func startJoinSequence() {
        if isDuringJoinSequence {
            return
        }
        isDuringJoinSequence = true
        guard let cam = getCameraPosition() else { return }
        let transform = SCNMatrix4MakeTranslation(cam.x, cam.y, cam.z)
        session.setWorldOrigin(relativeTransform: float4x4.init(transform))

        loadImage()
    }
    
    func alignWorldToCoordinator(vector: SCNVector3) {
        let translate = SCNMatrix4MakeTranslation(-vector.x, -vector.y, -vector.z)
        session.setWorldOrigin(relativeTransform: float4x4.init(translate))
        stopJoinSequence()
    }
    
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
        
        posMessageTimer = Timer.scheduledTimer(
                            timeInterval:0.05,
                            target: self,
                            selector: #selector(ViewController.sendCameraPos),
                            userInfo: nil,
                            repeats: true)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
        posMessageTimer?.invalidate()

        session.pause()
	}

    
    var cameraNode : SCNNode?
    
    @objc func sendCameraPos() {
        guard let camPos = self.getCameraPosition() else { return }
        let obj = ARObject(uuid: "camera-"+playerName, vector: camPos)
        netAppLayer?.sendCameraMessage(camera: obj)
        // let s = String(format: "Pos:[%.2f,%.2f,%.2f]",camPos.x,camPos.y,camPos.z)
        //self.statusViewController.showMessage(s)
        // print(s)
    }
    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true

    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        guard ARWorldTrackingConfiguration.isSupported else {
            statusViewController.showMessage("AR not supported, work for debug mode")
            return
        }
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.detectionImages = referenceImages

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        self.addAxisWorldOrigin()
        self.statusViewController.showMessage("Reseting world origin")
        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
	}

    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        updateQueue.async {
            
            // Create a plane to visualize the initial position of the detected image.
            let plane = SCNPlane(width: referenceImage.physicalSize.width,
                                 height: referenceImage.physicalSize.height)
            let planeNode = SCNNode(geometry: plane)
            planeNode.opacity = 0.75
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            planeNode.eulerAngles.x = -.pi / 2
            
            /*
             Image anchors are not tracked after initial detection, so create an
             animation that limits the duration for which the plane visualization appears.
             */
            planeNode.runAction(self.imageHighlightAction)
            
            // Add the plane visualization to the scene.
            node.addChildNode(planeNode)
        }
        
        updateQueue.async {
            self.sendWorldAlignmentMessage(vector: SCNMatrix4(anchor.transform).vector)
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

        DispatchQueue.main.async {
            let imageName = referenceImage.name ?? ""
            self.statusViewController.cancelAllScheduledMessages()
            self.statusViewController.showMessage("Detected image “\(imageName)”")
        }
    }

    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }
    
    private func getCameraPosition() -> SCNVector3? {
        guard let pointOfView = sceneView.pointOfView else { return nil }
        let transform = pointOfView.transform
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        return location
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }

    /*
    func moveWorldOriginBy(x: GLfloat, y: GLfloat, z: GLfloat) {
        // First let's get the current boxNode transformation matrix
        SCNMatrix4 boxTransform = boxNode.transform;
        
        // Let's make a new matrix for translation +2 along X axis
        SCNMatrix4 xTranslation = SCNMatrix4MakeTranslation(2, 0, 0);
        
        // Combine the two matrices, THE ORDER MATTERS !
        // if you swap the parameters you will move it in parent's coord system
        SCNMatrix4 newTransform = SCNMatrix4Mult(xTranslation, boxTransform);
        
        // Allply the newly generated transform
        boxNode.transform = newTransform;
        
        session.setWorldOrigin(relativeTransform: float4x4.init(transform))
    }
    */
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        //let transform = SCNMatrix4MakeTranslation(-1.0, 0, 0)
        //session.setWorldOrigin(relativeTransform: float4x4.init(transform))
        //let transform = SCNMatrix4MakeTranslation(0,0,0)

        
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        //let transform = SCNMatrix4MakeTranslation(0,0,0)
        //session.setWorldOrigin(relativeTransform: float4x4.init(m2))
        guard let node = hitTestResults.first?.node else {
            addBoxOnTouch()
            return
        }
        node.removeFromParentNode()
        
    }
    
    func addBoxOnTouch() {
        if let currentFrame = sceneView.session.currentFrame {
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -1.0
            let transform = simd_mul(currentFrame.camera.transform,translation)
            _ = addBoxOnTransform(id: "obj-"+UUID().uuidString, transform: SCNMatrix4(transform))
        }
    }
    
    func boxColor() -> [SCNMaterial] {
        let colors = [UIColor.green, // front
            UIColor.red, // right
            UIColor.blue, // back
            UIColor.yellow, // left
            UIColor.purple, // top
            UIColor.gray] // bottom
        
        return colors.map { color -> SCNMaterial in
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.locksAmbientWithDiffuse = true
            return material
        }
    }
    
    func addBoxOnTransform(id: String, transform: SCNMatrix4) -> SCNNode {
        let boxNode = SCNNode()
        let box = SCNBox(width: 0.05, height: 0.05, length: 0.05, chamferRadius: 0)
        box.materials = boxColor()
        boxNode.geometry = box
        boxNode.name = id
        boxNode.transform = transform
        sceneView.scene.rootNode.addChildNode(boxNode)
        return boxNode
    }

    func addBoxForAxis(width: CGFloat, height: CGFloat, length: CGFloat) {
        let boxNode = SCNNode()
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0)
        
        box.materials = boxColor()
        boxNode.geometry = box
        
        boxNode.transform = SCNMatrix4MakeTranslation(0,0,0)
        sceneView.scene.rootNode.addChildNode(boxNode)
    }
    
    func addAxisWorldOrigin() {
        addBoxForAxis(width: 0.50, height: 0.01, length: 0.01)
        addBoxForAxis(width: 0.01, height: 0.50, length: 0.01)
        addBoxForAxis(width: 0.01, height: 0.01, length: 0.50)
    }
    
}
