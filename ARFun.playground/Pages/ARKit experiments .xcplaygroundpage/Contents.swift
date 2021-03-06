/*
 * Copyright 2017 John M. P. Knox
 * Licensed under the MIT License - see license file
 */
import UIKit
import ARKit
import PlaygroundSupport

/**
 * A Simple starting point for AR experimentation in Swift Playgrounds 2
 */
class ARFun: NSObject, ARSCNViewDelegate {
    var nodeDict = [UUID:SCNNode]()
    //mark: ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if let node = nodeDict[anchor.identifier] {
            return node
        }
        return nil
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async { [weak self] in
            self?.debugView.log("updated node")
        }
    }
    
    let arSessionConfig = ARWorldTrackingConfiguration()
    
    let debugView = ARDebugView()
    
    var view:ARSCNView? = nil
    let scene = SCNScene()
    let useScenekit = true
    
    override init(){
        super.init()
        let frame = CGRect(x: 0.0, y: 0, width: 100, height: 100)
        let arView = ARSCNView(frame: frame)
        //configure the ARSCNView
        arView.debugOptions = [
            //ARSCNDebugOptions.showWorldOrigin,
            ARSCNDebugOptions.showFeaturePoints, 
//              SCNDebugOptions.showLightInfluences, 
//              SCNDebugOptions.showWireframe
        ]
        arView.showsStatistics = true
        arView.automaticallyUpdatesLighting = true
        debugView.translatesAutoresizingMaskIntoConstraints = false
        //add the debug view 
        arView.addSubview(debugView)
        arView.leadingAnchor.constraint(equalTo: debugView.leadingAnchor)
        arView.topAnchor.constraint(equalTo: debugView.topAnchor)
        
        view = arView
        arView.scene = scene
        
        //setup session config
        if !ARWorldTrackingConfiguration.isSupported { return }
        arSessionConfig.planeDetection = .horizontal
        arSessionConfig.worldAlignment = .gravityAndHeading //y-axis points UP, x points E (longitude), z points S (latitude)
        arSessionConfig.isLightEstimationEnabled = true
        arView.session.run(arSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        arView.delegate = self
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(viewTapped(gestureRecognizer:)))
        view?.addGestureRecognizer(gestureRecognizer)
    }
    
    let shouldAddAnchorsForNodes = true
    func addNode(node: SCNNode, worldTransform: matrix_float4x4) {
        let anchor = ARAnchor(transform: worldTransform)
        let position = vectorFrom(transform: worldTransform)
        node.position = position
        node.rotation = SCNVector4(x: 1, y: 1, z: 0, w: 0)
        nodeDict[anchor.identifier] = node
        if shouldAddAnchorsForNodes {
            view?.session.add(anchor: anchor)
        } else {
            scene.rootNode.addChildNode(node)
        }
    }
    
    func debug(sceneNode : SCNNode, prefix: String = "" ){
        debugView.log(prefix + (sceneNode.name ?? ""))
        for child in sceneNode.childNodes{
            debug(sceneNode: child, prefix: prefix + "-")
        }
    }
    
    func debug(scene: SCNScene, prefix: String = ""){
        debug(sceneNode: scene.rootNode)
    }
    
    ///returns a new node with a scene, if one can be found for the scene file specified
    func nodeFromScene(named fileName: String, inDirectory directoryName: String)-> SCNNode? {
        let scene = SCNScene(named: fileName, inDirectory: directoryName)
        
        guard let theScene = scene else {
            debugView.log("no scene \(fileName) in \(directoryName)")
            return nil
        }
        
        let node = SCNNode()
        
        for child in theScene.rootNode.childNodes {
            debugView.log("examining \(String(describing: child.name))")
            child.geometry?.firstMaterial?.lightingModel = .physicallyBased
            child.movabilityHint = .movable
            node.addChildNode(child)
        }
        return node
    }
    
    ///adds a new torus to the scene's root node
    func addTorus(worldTransform: matrix_float4x4 = matrix_identity_float4x4) {
        let torus = SCNTorus(ringRadius: 0.1, pipeRadius: 0.02)
        torus.firstMaterial?.diffuse.contents = UIColor(red: 0.4, green: 0, blue: 0, alpha: 1)
        torus.firstMaterial?.specular.contents = UIColor.white
        let torusNode = SCNNode(geometry:torus)
        let spin = CABasicAnimation(keyPath: "rotation.w")
        spin.toValue = 2 * Double.pi
        spin.duration = 3
        spin.repeatCount = HUGE
        torusNode.addAnimation(spin, forKey: "spin around")
        addNode(node: torusNode, worldTransform: worldTransform)
    }
    
    func makeLight()->SCNLight{
        let light = SCNLight()
        light.intensity = 1
        light.type = .omni
        light.color = UIColor.yellow
        light.attenuationStartDistance = 0.01
        light.attenuationEndDistance = 1
        return light 
    }
    
    func makeLightNode()->SCNNode{
        let light = makeLight()
        let node = SCNNode()
        var transform = matrix_identity_float4x4
        transform.columns.3.y = 0.2
        node.simdTransform = transform
        node.light = light
        node.simdTransform = transform
        return node
    }
    
    func addCandle(worldTransform: matrix_float4x4 = matrix_identity_float4x4) {
        guard let candleNode = nodeFromScene(named: "candle.scn", inDirectory: "Models.scnassets/candle") else {
            return
        }
        
        //candleNode.addChildNode(makeLightNode())
        
        addNode(node: candleNode, worldTransform: worldTransform)
    }
    
    func addTrex(worldTransform: matrix_float4x4 = matrix_identity_float4x4) {
        debugView.log("addTrex")
        guard let node = nodeFromScene(named: "Tyrannosaurus_jmpk2.scn", inDirectory: "/") else {
            return
        }
        addNode(node: node, worldTransform: worldTransform)
    }
    
    ///add a node where the scene was tapped
    @objc func viewTapped(gestureRecognizer: UITapGestureRecognizer){
        print("got tap: \(gestureRecognizer.location(in: view))")
        let hitTypes:ARHitTestResult.ResultType = [
            ARHitTestResult.ResultType.existingPlaneUsingExtent,
            //ARHitTestResult.ResultType.estimatedHorizontalPlane,
            //ARHitTestResult.ResultType.featurePoint
        ]
        if let hitTransform = view?.hitTest(gestureRecognizer.location(in: view), types: hitTypes).first?.worldTransform {
            addTrex(worldTransform: hitTransform)
            //addCandle(worldTransform: hitTransform) //TODO: use the anchor provided, if any?
        } else {
            debugView.log("no hit for tap")
        }
    }
    
    ///convert a transform matrix_float4x4 to a SCNVector3
    func vectorFrom(transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}

///vector addition and subtraction
extension SCNVector3 {
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
    }
}

let arFun = ARFun()
PlaygroundPage.current.liveView = arFun.view
PlaygroundPage.current.needsIndefiniteExecution = true


