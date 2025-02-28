import UIKit
//
import AVFoundation
//
import AWSCore
import AWSS3

class QRcodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, UICollectionViewDelegate, UICollectionViewDataSource {

    //set up collectionView and bind cell
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
    
    /*
    func collectionView(collectionView: UICollectionView, moveItemAtIndexPath sourceIndexPath: NSIndexPath,toIndexPath destinationIndexPath: NSIndexPath) {
    // swap values if sorce and destination
    let temp = characterArray[sourceIndexPath.row]
    characterArray[sourceIndexPath.row] = characterArray[destinationIndexPath.row]
    characterArray[destinationIndexPath.row] = temp
    }
    */
    
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    @IBOutlet weak var dishView: UIImageView!
    @IBOutlet weak var scanView: UIView!
    @IBOutlet weak var linkLabel: UILabel!
    @IBOutlet weak var dishThumbnailCollectionViewQR: UICollectionView!

    var dishUrlStringArray = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(getDataUpdate), name: NSNotification.Name(rawValue: dataModelDidUpdateNotification), object: nil)
        modifyComponents()
        createSession()
        addTapGestureToView()
    }
    
    @objc private func getDataUpdate() {   
        self.dishThumbnailCollectionViewQR.reloadData()
        self.dishView.image = VirtualObject.sharedInstance.dishes.last?.image
    }
    
    func modifyComponents() {
        scanView.layer.borderColor = UIColor.red.cgColor
        scanView.layer.borderWidth = 3

        linkLabel.layer.borderColor = UIColor.gray.cgColor
        linkLabel.layer.borderWidth = 1
        //masksToBounds: A Boolean indicating whether sublayers are clipped to the layer’s bounds
        linkLabel.layer.masksToBounds = true
        linkLabel.numberOfLines = 0
        linkLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        linkLabel.text = "name: XXX\nprice: XXX\ndescription: XXX"
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
            //
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
            //linkLabel.text = "No QR code detected, try adjusting camera position"
            return
        }
        // obtain the 1st metadata object and ignore secondary
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        // if metadata is QR code format, update linkLabel and boundry of QR code shown on screen
        if metadataObj.type == AVMetadataObject.ObjectType.qr {
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            //
            if metadataObj.stringValue != nil {
                let downloadUrl = metadataObj.stringValue!
                //linkLabel.text = downloadUrl
                //skip processing the same QR code, only respond with code not in database
                if(!dishUrlStringArray.contains(downloadUrl)) {
                    //food.downloadDataAWS(dishName: downloadUrl)
                    //VirtualObject.sharedInstance.downloadDataFromServer(url: downloadUrl)
                    VirtualObject.sharedInstance.handleUrl(url: downloadUrl)
                    //add url to array since it is scanned and downloaded
                    dishUrlStringArray.append(downloadUrl)
                }
            }
        }
    }
    
    func addTapGestureToView() {
        let collectionViewTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(QRcodeViewController.chooseCellInCollectionView(withGestureRecognizer:)))
        dishThumbnailCollectionViewQR.addGestureRecognizer(collectionViewTapGestureRecognizer)
        
        let collectionViewSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(QRcodeViewController.deleteCellInCollectionView(withGestureRecognizer:)))
        collectionViewSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirection.up
        dishThumbnailCollectionViewQR.addGestureRecognizer(collectionViewSwipeGestureRecognizer)
    }
    
    @objc func chooseCellInCollectionView(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: dishThumbnailCollectionViewQR)
        if let indexPath = dishThumbnailCollectionViewQR.indexPathForItem(at: tapLocation) {
            dishView.image = VirtualObject.sharedInstance.dishes[indexPath.row].image
            /*
            if let data = VirtualObject.sharedInstance.loadDataFromDirectory(fileName: "steak_diffuse.jpg") {
                dishView.image = UIImage(data: data)
            } else {
                print("file is nil")
            }
            */
        }
    }
    
    @objc func deleteCellInCollectionView(withGestureRecognizer recognizer: UISwipeGestureRecognizer) {
        let tapLocation = recognizer.location(in: dishThumbnailCollectionViewQR)
        if let indexPath = dishThumbnailCollectionViewQR.indexPathForItem(at: tapLocation) {
            VirtualObject.sharedInstance.dishes.remove(at: indexPath.row)
            print(dishThumbnailCollectionViewQR)

            dishUrlStringArray.remove(at: indexPath.row)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
}

