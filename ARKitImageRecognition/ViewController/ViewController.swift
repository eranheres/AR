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
    var handshakeSequence : HandshakeSequence?

    
    private var uiImage = UIImage(named:"iPhone X")
    //private var uiImageView : UIImageView?
    @IBOutlet var uiImageView: UIImageView!
    
    private var isDuringJoinSequence = false
    let locationManager = CLLocationManager()
    var trueHeading : CLHeading?
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
        
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        // Hook up status view controller callback(s).
        statusViewController.restartExperienceHandler = { [unowned self] in          self.restartExperience() }
        statusViewController.joinHandler = { [unowned self] in self.startJoinSequence() }
        statusViewController.handshakeHandler = { [unowned self] in
            self.startHandshake()
        }
        
        // Add tap gesture
        addTapGestureToSceneView()
        // Start network
        startNetwork()
        // Start location
        initLocationManager()
        // Start handshake sequence
        handshakeSequence = HandshakeSequence(delegate: self)
        
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
        guard let camPos = self.getCameraVectors()?.position else { return }
        let transform = SCNMatrix4MakeTranslation(camPos.x, camPos.y, camPos.z)
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
                            timeInterval:0.1,
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
        guard let obj = self.getCameraVectors() else { return }
        netAppLayer?.sendCameraMessage(camera: obj)
       // print("\(camDir)")
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
        configuration.planeDetection = .horizontal

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        self.addAxisWorldOrigin()
        self.statusViewController.showMessage("Reseting world origin")
        statusViewController.scheduleMessage("Look around to detect images", inSeconds: 7.5, messageType: .contentPlacement)
        
	}

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
            self.sendWorldAlignmentMessage(vector: SCNMatrix4(imageAnchor.transform).vector)
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
    
    func renderPlane(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for planeAnchor: ARPlaneAnchor) {
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        
        plane.materials.first?.diffuse.contents = UIColor.lightGray
        plane.materials.first?.transparency = 0.3
        let planeNode = SCNNode(geometry: plane)
        
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2
        
       // planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
      //  planeNode.physicsBody?.isAffectedByGravity = false
        
        node.addChildNode(planeNode)
    }
    
    // MARK: - ARSCNViewDelegate (Image detection results)
    /// - Tag: ARImageAnchor-Visualizing
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let imageAnchor = anchor as? ARImageAnchor {
            renderDetectedImage(renderer, didAdd: node, for: imageAnchor)
        }
        if let planeAnchor = anchor as? ARPlaneAnchor {
            renderPlane(renderer, didAdd: node, for: planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
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
    
    func getCameraVectors() -> CamObject? { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            let eulerAngles = frame.camera.eulerAngles
            let angle = SCNVector3(eulerAngles.x, eulerAngles.y, eulerAngles.z)
            return CamObject(player:"", pos:pos, dir:dir, angle:angle)
        }
        return nil
    }
    
    func addTapGestureToSceneView() {
        sceneView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(ViewController.handleLongPress(gestureReconizer:))))
    
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(ViewController.didTap(withGestureRecognizer:))))
    }
    
    var touchStart : Date?
    @objc func handleLongPress(gestureReconizer: UILongPressGestureRecognizer) {
        if gestureReconizer.state != UIGestureRecognizerState.ended {
            if touchStart == nil {
                touchStart = Date()
            }
            return
        }
        guard let time = touchStart?.timeIntervalSinceNow else { return }
        touchStart = nil
        throwBall(Float(-time))
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
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        guard let hitTestResult = hitTestResults.first else {
            addBoxOnTouch()
            return
        }
        
        let x = hitTestResult.worldCoordinates.x
        let y = hitTestResult.worldCoordinates.y+0.030
        let z = hitTestResult.worldCoordinates.z
        SCNMatrix4MakeTranslation(x,y,z)
        _ = addBoxOnTransform(id: "obj-"+UUID().uuidString, transform: SCNMatrix4MakeTranslation(x,y,z))

/*

        let node = hitTestResult.node
        if let _ = node.geometry as? SCNPlane {
            return
        }
        node.removeFromParentNode()
 */

        
    }
    
    func throwBall(_ distance : Float) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        let ballNode = SCNNode()
        let ball = SCNSphere(radius: 0.1)
        ball.materials = boxColor()
        ballNode.geometry = ball
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        
        // Ball start position
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -1.0
        let transform = simd_mul(currentFrame.camera.transform,translation)
        ballNode.transform = SCNMatrix4(transform)
        
        // Force direction & position
        translation.columns.3.z = Float(-distance*10)
        let tf = simd_mul(currentFrame.camera.transform,translation)
        let force = SCNVector3(x: tf.columns.3.x, y: tf.columns.3.y , z: tf.columns.3.z)
        let position = SCNVector3(x: 0.00, y: 0.00, z: 0.00)

        ballNode.physicsBody?.applyForce(force, at: position, asImpulse: true)
        sceneView.scene.rootNode.addChildNode(ballNode)
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
//      boxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
//      boxNode.physicsBody?.isAffectedByGravity = false
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
        let twoPointsNodeZ = SCNNode()
        sceneView.scene.rootNode.addChildNode(twoPointsNodeZ.buildLineInTwoPointsWithRotation(
            from: SCNVector3(0,0,0), to: SCNVector3(0,0,0.5), radius: 0.005, color: .red))
        let twoPointsNodeY = SCNNode()
        sceneView.scene.rootNode.addChildNode(twoPointsNodeY.buildLineInTwoPointsWithRotation(
            from: SCNVector3(0,0,0), to: SCNVector3(0,0.5,0), radius: 0.005, color: .cyan))
        let twoPointsNodeX = SCNNode()
        sceneView.scene.rootNode.addChildNode(twoPointsNodeX.buildLineInTwoPointsWithRotation(
            from: SCNVector3(0,0,0), to: SCNVector3(0.5,0,0), radius: 0.005, color: .yellow))
    }
    
    
}
