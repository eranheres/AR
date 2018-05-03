/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import SceneKit
import UIKit
import CoreLocation

class ViewController: UIViewController {
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    private var posMessageTimer: Timer?
    var mparEngine : MPAREngine = MPAREngine()
    var trueHeading : CLHeading? = nil
    
    private var uiImage = UIImage(named:"iPhone X")
    //private var uiImageView : UIImageView?
    @IBOutlet var uiImageView: UIImageView!
    
    private var isDuringJoinSequence = false
    let locationManager = CLLocationManager()
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
        let errorHandler = ErrorHandler(delegate: self.statusViewController.errorHandlerDelegate)
        statusViewController.restartExperienceHandler = { [unowned self] in self.restartExperience() }
        statusViewController.errorHandler = errorHandler
        statusViewController.handshakeHandler = { [unowned self] in self.mparEngine.startHandshake() }

        // Hook up MPAREngine dependencies
        mparEngine.sceneView = sceneView
        mparEngine.trueHeading = { return self.trueHeading }
        mparEngine.statusReportHandler = { ok, str in
            if ok {
                errorHandler.reportOK(module: .connection)
            } else {
                errorHandler.reportError(module: .connection, str: str)
            }
        }
        
        // Add tap gesture
        addTapGestureToSceneView()
    }
    
    @objc func didTapImage() {
//        stopJoinSequence()
    }
    
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience.
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the AR experience
        resetTracking()
        
        // Strat the MPAR engine
        initLocationManager()
        mparEngine.start()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
        posMessageTimer?.invalidate()

        session.pause()
	}

    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true

    /// Creates a new AR configuration to run on the `session`.
    /// - Tag: ARReferenceImage-Loading
	func resetTracking() {
        guard ARWorldTrackingConfiguration.isSupported else {
            statusViewController.errorHandler?.reportError(module: .ar, str: "AR not supported, work for debug mode")
            return
        }
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        // configuration.detectionImages = referenceImages
        configuration.planeDetection = [.horizontal, .vertical]

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        self.addAxisWorldOrigin()
        statusViewController.errorHandler?.reportError(module: .ar, str: "Reseting AR session")
        
        Timer.scheduledTimer(withTimeInterval: 7.5, repeats: false, block: {_ in
            self.statusViewController.errorHandler?.reportOK(module: .ar)
        })
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
        guard let _ = touchStart?.timeIntervalSinceNow else { return }
        touchStart = nil
        addJumper()
//      throwBall(Float(-time))
    }
    
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        // addNormalFloatingBox(withGestureRecognizer: recognizer)
        fireOnJumper(withGestureRecognizer: recognizer)
    }
    
    func addNormalFloatingBox(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        guard let hitTestResult = hitTestResults.first else {
            addBoxOnTouch()
            return
        }
        
        let x = hitTestResult.worldCoordinates.x
        let y = hitTestResult.worldCoordinates.y
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
    
    func addJumper() {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -1.0
        let transform = SCNMatrix4(simd_mul(currentFrame.camera.transform,translation))
        
        let jumper = Jumper()
        jumper.scene = self.sceneView.scene
        jumper.start(pos: SCNVector3(transform.m41, transform.m42, transform.m43))
    }
    
    func fireOnJumper(withGestureRecognizer recognizer: UIGestureRecognizer) {
        var endPoint : SCNVector3?
        
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        if let hitTestResult = hitTestResults.first {
            let x = hitTestResult.worldCoordinates.x
            let y = hitTestResult.worldCoordinates.y
            let z = hitTestResult.worldCoordinates.z
            endPoint = SCNVector3(x,y,z)
            if let jumper = hitTestResult.node as? Jumper {
                jumper.takeHit()
            }
        }
        
        let shoot = Shoot()
        shoot.scene = sceneView.scene
        shoot.start(camera: (mparEngine.getCameraVectors())!, hitWorldCoordinates: endPoint)
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
        boxNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        // boxNode.physicsBody?.isAffectedByGravity = false
        sceneView.scene.rootNode.addChildNode(boxNode)
        return boxNode
    }

    func addAxisWorldOrigin() {
        let twoPointsNodeZ = SCNNode()
        sceneView.scene.rootNode.addChildNode(twoPointsNodeZ.buildLineInTwoPointsWithRotation(
            from: SCNVector3(0,0,0), to: SCNVector3(0,0,0.1), radius: 0.001, color: .red))
        let twoPointsNodeY = SCNNode()
        sceneView.scene.rootNode.addChildNode(twoPointsNodeY.buildLineInTwoPointsWithRotation(
            from: SCNVector3(0,0,0), to: SCNVector3(0,0.1,0), radius: 0.001, color: .cyan))
        let twoPointsNodeX = SCNNode()
        sceneView.scene.rootNode.addChildNode(twoPointsNodeX.buildLineInTwoPointsWithRotation(
            from: SCNVector3(0,0,0), to: SCNVector3(0.1,0,0), radius: 0.001, color: .yellow))
    }
    
    
}
