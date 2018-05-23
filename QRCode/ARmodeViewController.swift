//see ARKit intro @ https://juejin.im/post/5ad0e8975188255c9323b490

import UIKit
import ARKit

class ARmodeViewController: UIViewController, ARSCNViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {

    var food = VirtualObject()
    
    //Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return VirtualObject.sharedInstance.dishes.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "dishThumbnailCell", for: indexPath) as! dishThumbnailCollectionViewCell
        cell.dishThumbnailImageView.image = VirtualObject.sharedInstance.dishes[indexPath.row].image
        return cell
    }
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet var didTapScreen: UITapGestureRecognizer!
    @IBOutlet weak var dishThumbnailCollectionViewAR: UICollectionView!
    @IBOutlet weak var arStatus: UILabel!
    @IBAction func testButton(_ sender: Any) {
        self.restartSession()
    }
    
    func restartSession() {
        /*
        sceneView.session.pause()
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
        sceneView.session.run(ARWorldTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        sceneView.scene = scene
        */
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(getDataUpdate), name: NSNotification.Name(rawValue: dataModelDidUpdateNotification), object: nil)
        VirtualObject.sharedInstance.requestData()
        /*
        if let sceneTest = SCNScene(named: "art.scnassets/book/book.scn") {
            //sceneTest.position =SCNVector3(0,0, -0.2)
            sceneView.scene = sceneTest
        } else {
            print("failed sceneTest")
        }
        */
        
        configureLighting()
        setUpSceneView()
        addTapGestureToView()
    }
    
    @objc func getDataUpdate() {
        self.dishThumbnailCollectionViewAR.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView.session.run(configuration, options: ARSession.RunOptions.resetTracking)
    }
    
    func setUpSceneView() {
        //detect the horizontal plane and added into sceneView’s session.
        configuration.planeDetection = .horizontal
        //Run the view's session
        sceneView.session.run(configuration)
        //Set the view's delegate
        sceneView.delegate = self
        //show feature points in the world
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }

    //Once enough ARAnchor(object represents physical location & orientation in 3D space) is added renderer will be called
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        //create an SCNPlane to visualize the ARPlaneAnchor with x, z and make the color transparentLightBlue
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)
        plane.materials.first?.diffuse.contents = UIColor.transparentLightBlue
        
        //initialize a SCNNode with the SCNPlane geometry
        let planeNode = SCNNode(geometry: plane)
        
        //rotate planeNode’s x euler angle by 90 in counter-clockerwise, else planeNode will sit up perpendicular to the table
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2
        
        node.addChildNode(planeNode)
    }
    
    //expand horizontal planes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        //
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        //update the plane’s width and height
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height
        
        //update the planeNode’s position to center of planeAnchor
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x, y, z)
    }
    
    func configureLighting() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    
    func addTapGestureToView() {
        
        
        let collectionViewTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(QRcodeViewController.chooseCellInCollectionView(withGestureRecognizer:)))
        dishThumbnailCollectionViewAR.addGestureRecognizer(collectionViewTapGestureRecognizer)
        
        let sceneViewTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ARmodeViewController.addObjectToSceneView(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(sceneViewTapGestureRecognizer)
    }
    
    @objc func chooseCellInCollectionView(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: dishThumbnailCollectionViewAR)
        if let indexPath = dishThumbnailCollectionViewAR.indexPathForItem(at: tapLocation) {
            //dishView.image = VirtualObject.sharedInstance.dishes[indexPath.row].image
            //project selected image's AR at sceneView
        }
    }
    
    var objectAlreadyExist = false
    @objc func addObjectToSceneView(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
        
        guard let hitTestResult = hitTestResults.first else { return }
        let translation = hitTestResult.worldTransform.translation
        let x = translation.x
        let y = translation.y
        let z = translation.z
        
        guard let objectScene = SCNScene(named: "art.scnassets/burger/burger.scn"),
            let objectNode = objectScene.rootNode.childNode(withName: "burger", recursively: false)
            else { return }
        
        print("object added")
        
        //place object if not on table yet
        if (objectAlreadyExist != true) {
            objectNode.position = SCNVector3(x,y,z)
            sceneView.scene.rootNode.addChildNode(objectNode)
            objectAlreadyExist = true
        //delete object if it it exist
        } else {
            sceneView.scene.rootNode.childNode(withName: "burger", recursively: true)?.removeFromParentNode()
            objectAlreadyExist = false
            /*
            sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                node.removeFromParentNode()
            objectAlreadyExist = false
            }
            */
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }

    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}

extension UIColor {
    open class var transparentLightBlue: UIColor {
        return UIColor(red: 90/255, green: 200/255, blue: 250/255, alpha: 0.50)
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return float3(translation.x, translation.y, translation.z)
    }
}
