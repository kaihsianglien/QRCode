import UIKit
//
import AVFoundation
//
import AWSCore
import AWSS3

class QRcodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    
    let images = ["book1", "book2", "book3", "book4", "book5", "book6", "book7", "book8", "book9", "book10", "book11", "book12", "book13", ]

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "dishThumbnailCell", for: indexPath) as! dishThumbnailCollectionViewCell
        cell.dishThumbnailImageView.image = UIImage(named: images[indexPath.row])
        cell.backgroundColor = UIColor.gray
        return cell
    }
    
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    @IBOutlet weak var dishView: UIImageView!
    @IBOutlet weak var scanView: UIView!
    @IBOutlet weak var linkLabel: UILabel!
    
    var previousString = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        modifyComponents()
        createSession()
    }
    
    func modifyComponents() {
        //rounded corners and shadows can't exist within one layer in swift, see
        //https://medium.com/swifty-tim/views-with-rounded-corners-and-shadows-c3adc0085182
        //dishView.layer.cornerRadius = 10
        //dishView.layer.masksToBounds = true
        
        dishView.layer.shadowColor = UIColor.black.cgColor
        dishView.layer.shadowOffset = CGSize(width: 5, height: 5)
        dishView.layer.shadowRadius = 3;
        dishView.layer.shadowOpacity = 0.8;
        
        scanView.layer.borderColor = UIColor.red.cgColor
        scanView.layer.borderWidth = 3
        
        linkLabel.layer.cornerRadius = 20
        linkLabel.layer.borderColor = UIColor.gray.cgColor
        linkLabel.layer.borderWidth = 1
        //masksToBounds: A Boolean indicating whether sublayers are clipped to the layer’s bounds
        linkLabel.layer.masksToBounds = true
    }
    
     override func viewDidAppear(_ animated: Bool) {
     super.viewDidAppear(animated)
     //videoPreviewLayer?.frame.size = scanView.frame.size
     }
    
    func createSession() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.back)
        
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
            
            //initialize AVCaptureMetadataOutput to intercept metadata(QR code) and convert to readable format
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            //
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            //the metadata should be converted via QR .qr type
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
            //initial previewlayer and add as sublayer
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            
            videoPreviewLayer?.frame = scanView.layer.frame
            view.layer.addSublayer(videoPreviewLayer!)
            
            //start capturing vedio
            captureSession.startRunning()
            
            //!!! rectOfInterest has an UPRIGHT origin with value 0~1
            //use metadataOutputRectConverted to convert coordinate, beware this has to be under captureSession.startRunning()
            //TODO: sort out boundary
            if let convertedRectRegion = videoPreviewLayer?.metadataOutputRectConverted(fromLayerRect: view.layer.frame){
                captureMetadataOutput.rectOfInterest = convertedRectRegion
            }
            
            // initialize QR Code frame which appears when a code is found
            qrCodeFrameView = UIView()
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
                view.bringSubview(toFront: dishView)
            }
            
        } catch {
            // catch if error occures and end the application
            print(error)
            return
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // check metadataObjects arrays as it should at least has one object of QR code
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            linkLabel.text = "No QR code detected, try adjusting camera position"
            return
        }
        
        // obtain the 1st metadata object and ignore secondary
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        // if metadata is QR code format, update linkLabel and boundry of QR code shown on screen
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                linkLabel.text = metadataObj.stringValue
                
                //skip processing the same QR code, only respond with different code
                if(previousString != metadataObj.stringValue) {
                    //AWS download function
                    //downloadData(dishName: metadataObj.stringValue!)
                    
                    //this is the direct download without AWS
                    downloadDataDirectMethod(metadataObj: metadataObj)
                    previousString = metadataObj.stringValue!
                }
            }
        }
    }
    
    func downloadData(dishName: String) {
        let expression = AWSS3TransferUtilityDownloadExpression()
        expression.progressBlock = {(task, progress) in DispatchQueue.main.async(execute: {
            // Do something e.g. Update a progress bar.
            //Reference to property 'linkLabel' in closure requires explicit 'self.' to make capture semantics explicit
        })
        }
        
        var completionHandler: AWSS3TransferUtilityDownloadCompletionHandlerBlock?
        completionHandler = { (task, URL, data, error) -> Void in
            DispatchQueue.main.async(execute: {
                if let error = error {
                    print("localizedDescription: \(error.localizedDescription)")
                    NSLog("Failed with error: \(error)")
                }
                else{
                    self.dishView.image = UIImage(data: data!)
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
                return nil;
        }
    }
    
    func downloadDataDirectMethod(metadataObj: AVMetadataMachineReadableCodeObject) {
        if let URL_IMAGE = URL(string: metadataObj.stringValue!){
            
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
                            let image = UIImage(data: imageData)
                            //view must be used from main thread only, see https://developer.apple.com/documentation/code_diagnostics/main_thread_checker
                            DispatchQueue.main.async {
                                self.dishView.image = image
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

