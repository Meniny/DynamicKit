//
//  ViewController.swift
//  Sample
//
//  Created by 李二狗 on 2018/5/12.
//  Copyright © 2018年 Meniny Lab. All rights reserved.
//

import UIKit
import DynamicKit

class LayoutViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet internal var leftField: UITextField!
    @IBOutlet internal var topField: UITextField!
    @IBOutlet internal var widthField: UITextField!
    @IBOutlet internal var heightField: UITextField!
    @IBOutlet internal var errorLabel: UILabel!
    
    @IBOutlet internal var layoutView: UIView!
    
    var selectedView: UIView? {
        didSet {
            oldValue?.layer.borderWidth = 0
            selectedView?.layer.borderWidth = 2
            selectedView?.layer.borderColor = UIColor.black.cgColor
            leftField.isEnabled = true
            leftField.text = selectedView?.left
            topField.isEnabled = true
            topField.text = selectedView?.top
            widthField.isEnabled = true
            widthField.text = selectedView?.width
            heightField.isEnabled = true
            heightField.text = selectedView?.height
        }
    }
    
    @IBAction func didTap(sender: UITapGestureRecognizer) {
        let point = sender.location(in: layoutView)
        if let view = layoutView.hitTest(point, with: nil), view != layoutView {
            selectedView = view
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayout()
    }
    
    func updateLayout() {
        do {
            for view in layoutView.subviews {
                try view.updateLayoutFromExpressions()
            }
            errorLabel.text = nil
        } catch {
            errorLabel.text = "\(error)"
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_: UITextField) {
        selectedView?.left = leftField.text
        selectedView?.top = topField.text
        selectedView?.width = widthField.text
        selectedView?.height = heightField.text
        updateLayout()
    }
}
