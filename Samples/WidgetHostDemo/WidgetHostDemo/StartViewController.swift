//
//  StartViewController.swift
//  WidgetHostDemo
//
//  Created by Marat on 17/06/2018.
//  Copyright © 2018 M8 Labs. All rights reserved.
//

import WidgetKit

class StartViewController: UIViewController {
    
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    
    @IBAction func downloadAction(_ sender: UIButton) {
        sender.isEnabled = false
        activityIndicatorView.startAnimating()
        Widget.run(url: ApplicationMain.url, identifier: "mobi.favio.WidgetDemo") { widget, error in
            sender.isEnabled = true
            self.activityIndicatorView.stopAnimating()
            if error != nil {
                self.showAlert(title: "Error", message: "\(error!)")
            }
        }
    }
}
