//
//  HostViewController.swift
//  WidgetDemo
//
//  Created by Marat on 24/05/2018.
//  Copyright © 2018 M8 Labs. All rights reserved.
//

import WidgetKit

class HostViewController: UIViewController {
    
    @IBOutlet var remoteWidgetView: WidgetView!
    
    @IBAction func downloadAction(_ sender: UIButton) {
        sender.isEnabled = false
        remoteWidgetView.download(url: ApplicationMain.url) { widget, error in
            sender.isEnabled = true
            sender.isHidden = error == nil
        }
    }
}
