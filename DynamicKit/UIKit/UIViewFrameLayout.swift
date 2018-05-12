
import Foundation
import UIKit

@IBDesignable public extension UIView {
    internal var layout: UIViewFrameLayoutData? {
        return layout(create: false)
    }

    internal func layout(create: Bool) -> UIViewFrameLayoutData! {
        let l = layer.value(forKey: "layout") as? UIViewFrameLayoutData
        if l == nil && create {
            let ld = UIViewFrameLayoutData(self)
            layer.setValue(ld, forKey: "layout")
            return layout
        }
        return l
    }

    @IBInspectable public var key: String? {
        get { return layout?.key }
        set { layout(create: true).key = newValue }
    }

    @IBInspectable public var left: String? {
        get { return layout?.left }
        set { layout(create: true).left = newValue }
    }

    @IBInspectable public var top: String? {
        get { return layout?.top }
        set { layout(create: true).top = newValue }
    }

    @IBInspectable public var width: String? {
        get { return layout?.width }
        set { layout(create: true).width = newValue }
    }

    @IBInspectable public var height: String? {
        get { return layout?.height }
        set { layout(create: true).height = newValue }
    }

    public func subview(forKey key: String) -> UIView? {
        if self.key == key {
            return self
        }
        for view in subviews {
            if let match = view.subview(forKey: key) {
                return match
            }
        }
        return nil
    }

    public func updateLayoutFromExpressions() throws {
        guard let layout = self.layout(create: true) else {
            return
        }
        frame = CGRect(x: try layout.computedValue(forKey: "left"),
                       y: try layout.computedValue(forKey: "top"),
                       width: try layout.computedValue(forKey: "width"),
                       height: try layout.computedValue(forKey: "height"))

        for view in subviews {
            try view.updateLayoutFromExpressions()
        }
    }
}
