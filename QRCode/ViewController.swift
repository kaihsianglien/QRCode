import UIKit
//
import AVFoundation

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    @IBOutlet weak var dishView: UIImageView!
    @IBOutlet weak var scanView: UIView!
    @IBOutlet weak var linkLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createSession()
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
            
            //make linkLabel to front to be visible
            view.bringSubview(toFront: linkLabel)
            
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        }
    }
}

