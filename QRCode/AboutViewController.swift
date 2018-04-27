//
//  AboutViewController.swift
//  QRCode
//
//  Created by kevinlien on 2018/4/26.
//  Copyright © 2018年 Lien. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

     @IBOutlet weak var userTutorialLabel: UILabel!
    @IBOutlet weak var companyInformationLabel: UILabel!
    @IBOutlet weak var reviewLabel: UILabel!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let backgroundImage = UIImageView(frame: UIScreen.main.bounds)
        backgroundImage.image = UIImage(named: "background3.jpg")
        backgroundImage.contentMode = UIViewContentMode.scaleAspectFill
        self.view.insertSubview(backgroundImage, at: 0)

        userTutorialLabel.numberOfLines = 0
        userTutorialLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        userTutorialLabel.text = "Tap on screen to place dishes\nTap again to delete"
        
        companyInformationLabel.numberOfLines = 0
        companyInformationLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        companyInformationLabel.text = "introduction here"
        
        reviewLabel.numberOfLines = 0
        reviewLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        reviewLabel.text = "Want to write a review?\nHave some suggestion?\nWe are Happy to hear!"
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
   
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
