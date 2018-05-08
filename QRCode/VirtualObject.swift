import Foundation
import SceneKit
import ARKit
import AWSCore
import AWSS3

struct CellContent {
    let url: String
    let image: UIImage
}

protocol VirtualObjectQRDelegate: class {
    func virtualObjectToQRcodeDelegate(url: String, img: UIImage)
}

protocol VirtualObjectARDelegate: class {
    func virtualObjectToARmodeDelegate(url: String, img: UIImage)
}

let dataModelDidUpdateNotification = "dataModelDidUpdateNotification"

var imageUrlStringType = "" {
    didSet {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: dataModelDidUpdateNotification), object: nil)
    }
}

class VirtualObject {
 
    weak var delegateQR: VirtualObjectQRDelegate?
     weak var delegateAR: VirtualObjectARDelegate?
    
    static var sharedInstance = VirtualObject()

    func getDataOfDishes() -> String {
        //print("getDataOfDishes", imageUrlStringType)
        return imageUrlStringType
    }
    
    var dishes = [CellContent]()
    
    init() {
    }
    
    func downloadDataDirectMethod(metadataObj: AVMetadataMachineReadableCodeObject) {
        imageUrlStringType = metadataObj.stringValue!
        if let URL_IMAGE = URL(string: imageUrlStringType){
            
            // Creating a session object with the default configuration.
            // You can read more about it here https://developer.apple.com/reference/foundation/urlsessionconfiguration
            let session = URLSession(configuration: .default)
            
            // Define a download task. The download task will download the contents of the URL as a Data object
            let getImageFromUrl = session.dataTask(with: URL_IMAGE) { (data, response, error) in
                // The download has finished. if there is any error
                if let e = error {
                    print("Error Occurred: \(e)")
                } else {
                    // No errors found.
                    if (response as? HTTPURLResponse) != nil {
                        //checking if the response contains an image
                        if let imageData = data {
                            //convert that Data into an image
                            let downloadImage = UIImage(data: imageData)
                            //view must be used from main thread only, see https://developer.apple.com/documentation/code_diagnostics/main_thread_checker
                            DispatchQueue.main.async {
                                self.dishes.append(CellContent(url: imageUrlStringType, image: downloadImage!))
                                self.delegateQR?.virtualObjectToQRcodeDelegate(url: imageUrlStringType, img: downloadImage!)
                                self.delegateAR?.virtualObjectToARmodeDelegate(url: imageUrlStringType, img: downloadImage!)
                                
                                //self.dataOfDishes = imageUrlStringType
                            }
                        } else {
                            print("Couldn't get image: Image is nil")
                        }
                    } else {
                        print("Couldn't get response code for some reason")
                    }
                }
            }
            //starting the download task
            getImageFromUrl.resume()
        }
    }
    
    func downloadDataAWS(dishName: String) {
        let expression = AWSS3TransferUtilityDownloadExpression()
        expression.progressBlock = {(task, progress) in DispatchQueue.main.async(execute: {
            // Do something e.g. Update a progress bar.
            //Reference to property 'linkLabel' in closure requires explicit 'self.' to make capture semantics explicit
        })
        }
        
        var downloadImage = UIImage()
        
        var completionHandler: AWSS3TransferUtilityDownloadCompletionHandlerBlock?
        completionHandler = { (task, URL, data, error) -> Void in
            DispatchQueue.main.async(execute: {
                if let error = error {
                    print("localizedDescription: \(error.localizedDescription)")
                    NSLog("Failed with error: \(error)")
                }
                else{
                    downloadImage = UIImage(data: data!)!
                    
                    self.dishes.append(CellContent(url: dishName, image: downloadImage))
                    self.delegateQR?.virtualObjectToQRcodeDelegate(url: dishName, img: downloadImage)
                    self.delegateAR?.virtualObjectToARmodeDelegate(url: dishName, img: downloadImage)
                }
            })
        }
        let transferUtility = AWSS3TransferUtility.default()
        transferUtility.downloadData(
            fromBucket: "restaurantdishphoto",
            //beware the filetype is fixed to jpg format
            key: dishName+".jpg",
            expression: expression,
            completionHandler: completionHandler
            ).continueWith {
                (task) -> AnyObject! in if let error = task.error {
                    print("Error: \(error.localizedDescription)")
                }
                
                if let _ = task.result {
                    // Do something with downloadTask.
                }
                return nil
        }
    }
}

/*
class VirtualObject: SCNReferenceNode {
    
    /// - Tag: AdjustOntoPlaneAnchor
    func adjustOntoPlaneAnchor(_ anchor: ARPlaneAnchor, using node: SCNNode) {
        // Get the object's position in the plane's coordinate system.
        let planePosition = node.convertPosition(position, from: parent)
        
        // Check that the object is not already on the plane.
        guard planePosition.y != 0 else { return }
        
        // Add 10% tolerance to the corners of the plane.
        let tolerance: Float = 0.1
        
        let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
        let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
        let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
        let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
        
        guard (minX...maxX).contains(planePosition.x) && (minZ...maxZ).contains(planePosition.z) else {
            return
        }
        
        // Move onto the plane if it is near it (within 5 centimeters).
        let verticalAllowance: Float = 0.05
        let epsilon: Float = 0.001 // Do not update if the difference is less than 1 mm.
        let distanceToPlane = abs(planePosition.y)
        if distanceToPlane > epsilon && distanceToPlane < verticalAllowance {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = CFTimeInterval(distanceToPlane * 500) // Move 2 mm per second.
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
            position.y = anchor.transform.columns.3.y
            SCNTransaction.commit()
        }
    }
}

extension VirtualObject {
    // MARK: Static Properties and Methods
    
    /// Loads all the model objects within `Models.scnassets`.
    static let availableObjects: [VirtualObject] = {
        let modelsURL = Bundle.main.url(forResource: "art.scnassets", withExtension: nil)!
        
        let fileEnumerator = FileManager().enumerator(at: modelsURL, includingPropertiesForKeys: [])!
        
        return fileEnumerator.flatMap { element in
            let url = element as! URL
            
            guard url.pathExtension == "scn" else { return nil }
            
            return VirtualObject(url: url)
        }
    }()
    
    /// Returns a `VirtualObject` if one exists as an ancestor to the provided node.
    static func existingObjectContainingNode(_ node: SCNNode) -> VirtualObject? {
        if let virtualObjectRoot = node as? VirtualObject {
            return virtualObjectRoot
        }
        
        guard let parent = node.parent else { return nil }
        
        // Recurse up to check if the parent is a `VirtualObject`.
        return existingObjectContainingNode(parent)
    }
}
*/

