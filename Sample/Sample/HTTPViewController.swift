//
//  HTTPViewController.swift
//  Sample
//
//  Created by Meniny on 2018-05-12.
//  Copyright © 2018年 Meniny Lab. All rights reserved.
//

import Foundation
import UIKit
import DynamicKit

class HTTPViewController: UIViewController {
    @IBOutlet internal var label: UILabel!
    
    let client = HTTP.Client.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = URL.init(string: "https://meniny.cn/api/v2/posts.json") {
            
            let request = HTTP.Request.init(url: url)
            
            self.client.send(request, transformer: DataToJSONTransformer(), completion: { (result) in
                self.label.text = "\(result)"
            }) { (error) in
                self.label.text = error.localizedDescription
            }
        }
    }
}
