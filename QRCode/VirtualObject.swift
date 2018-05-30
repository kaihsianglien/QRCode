import Foundation
import SceneKit
import ARKit
import AWSCore
import AWSS3

struct CellContent {
    var url: String
    var image: UIImage
    var scnObject: Data
    var renderPic: UIImage
    
    mutating func addUrl(url: String) {
        self.url = url
    }
}



let dataModelDidUpdateNotification = "dataModelDidUpdateNotification"

class VirtualObject {
    
    static var sharedInstance = VirtualObject()
    
    var dishes = [CellContent]() {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: dataModelDidUpdateNotification), object: nil)
        }
    }
    
    var dlUrl = ""
    var dlImage = UIImage()
    var dlScnObject = Data()
    var dlRenderPic = UIImage()
    
    func handleUrl(url: String) {
        /*
        let start = url.index(url.startIndex, offsetBy: serverAddress.count)
        let end = url.index(url.endIndex, offsetBy: -1)
        let range = start ..< end
        let itemName = url[range]
        */
        let serverAddress = "http://www-scf.usc.edu/~klien/menu/"
        let documentPath = url + "/"
        let urlImage = serverAddress + documentPath + url + ".jpg"
        let urlScnObject = serverAddress + documentPath + url + ".scn"
        let urlDiffuse = serverAddress + documentPath + url + "_diffuse.jpg"
        
        self.dlUrl = url
        
        var arrayForUrls  = [(url: String, fileType: String)]()
        arrayForUrls.append((urlImage, "urlImage"))
        arrayForUrls.append((urlScnObject, "urlScnObject"))
        arrayForUrls.append((urlDiffuse, "urlDiffuse"))
        
        self.downloadDataFromServer(arrayForUrls: arrayForUrls)
    }
    
    func downloadDataFromServer(arrayForUrls: [(url: String, fileType: String)]) {
        // Read more about it here https://developer.apple.com/reference/foundation/urlsessionconfiguration
        let session = URLSession(configuration: .default)
        let group = DispatchGroup()
        for tupleInArray in arrayForUrls {
            var url = URL(string: tupleInArray.url)!
            group.enter()
            // Define a download task. The download task will download the contents of the URL as a Data object
            let getImageFromUrl = session.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
                // The download has finished. if there is any error
                if let e = error {
                    print("Error Occurred: \(e)")
                } else {
                    // No errors found.
                    if (response as? HTTPURLResponse) != nil {
                        self.processDownloadedData(fileName: url.lastPathComponent, data: data, fileType: tupleInArray.fileType)
                    } else {
                        print("Couldn't get response code for some reason")
                    }
                }
                group.leave()
            })
            //starting the download task
            getImageFromUrl.resume()
            
        }
        group.notify(queue: .main) {
            //print(self.dlUrl)
            //print(self.dlImage)
            //print(self.dlScnObject)
            //print(self.dlRenderPic)
            self.dishes.append(CellContent(url: self.dlUrl, image: self.dlImage, scnObject: self.dlScnObject, renderPic: self.dlRenderPic))
            //print(self.dishes)
        }
    }
    
    func processDownloadedData(fileName: String, data: Data?, fileType: String) {
        
        if let Data = data {
            switch fileType {
            case "urlScnObject":
                self.dlScnObject = Data
                saveDataToDirectory(fileName: fileName, data: Data)
            case "urlImage":
                if let downloadImage = UIImage(data: Data) {
                    //view must be used from main thread only, see https://developer.apple.com/documentation/code_diagnostics/main_thread_checker
                    self.dlImage = downloadImage
                }
            case "urlDiffuse":
                if let downloadImage = UIImage(data: Data) {
                    self.dlRenderPic = downloadImage
                    saveDataToDirectory(fileName: fileName, data: Data)
                }
            default:
                break
            }
        }
    }
    
    func saveDataToDirectory(fileName: String, data: Data) {
        // create your document folder url
        let tmpURL = FileManager.default.temporaryDirectory
        // your destination file url
        let destination = tmpURL.appendingPathComponent(fileName)//URL.lastPathComponent
        //print("destination: \(destination.absoluteString)")
        // check if it exists before downloading it
        if FileManager().fileExists(atPath: destination.path) {
            //print("The file already exists at path")
        } else {
            do {
                try data.write(to: destination, options: [.atomic])
                //FileManager.default.createFile(atPath: <#T##String#>, contents: <#T##Data?#>, attributes: <#T##[FileAttributeKey : Any]?#>)
                //print("new file saved")
            } catch {
                print(error)
            }
        }
    }
    
    func loadDataFromDirectory(fileName: String) -> Data? {
        //print("fileName: \(fileName)")
        let tmpURL = FileManager.default.temporaryDirectory
        let targetLocation = tmpURL.appendingPathComponent(fileName).path
        //print("targetLocation: \(targetLocation)")
        let data:Data? = try? Data(contentsOf: URL(fileURLWithPath: targetLocation))
        return data
    }
    /*
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
                    
                    //self.dishes.append(CellContent(url: dishName, image: downloadImage))
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
    */
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
/*
extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
}
FileManager.default.clearTmpDirectory()
 */
